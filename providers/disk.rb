# Copyright 2014 Google Inc. All Rights Reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

include Google::Gce

# Support whyrun
def whyrun_supported?
  true
end

action :create do
  Chef::Log.debug("Attempting to create disk #{new_resource.name}")
  begin
    if new_resource.source_snapshot && new_resource.source_image
      raise "Can not define both source_snapshot and source_image"
    end
    opts = {
      :name => new_resource.name,
      :zone_name => new_resource.zone_name,
      :size_gb => new_resource.size_gb
    }
    if new_resource.source_snapshot
      opts[:source_snapshot] = new_resource.source_snapshot
      opts[:description] = new_resource.description || "Created from snapshot: #{new_resource.source_snapshot}"
    end
    if new_resource.source_image
      opts[:source_image] = new_resource.source_image
      opts[:description] = new_resource.description || "Created from image: #{new_resource.source_image}"
    end
    converge_by("create disk #{new_resource.name}") do
      disk = gce.disks.create(opts)
      disk.wait_for { disk.ready? } if new_resource.wait_for
    end
  rescue => e
    Chef::Log.debug(e.message)
    raise "#{e.message}"
  end
  Chef::Log.debug("Completed creating disk #{new_resource.name}")
end

action :delete do
  Chef::Log.debug("Attempting to delete disk #{new_resource.name}")
  converge_by("delete disk #{new_resource.name}") do
    # if disk is not found, that should be OK since user wants it gone anyway
    begin
      disk = gce.disks.get(new_resource.name)
      disk.destroy
    rescue
      Chef::Log.debug("Disk #{new_resource.name} not found, nothing to delete")
    end
    # TODO unregister from chef node if attached
  end
  Chef::Log.debug("Completed deleting disk #{new_resource.name}")
end

action :attach do
  begin
    Chef::Log.debug("Attempting to attach disk #{new_resource.name}")
    # instance and zone are names only, not selfLinks
    # source needs to be a selfLink, return first match as a hash
    source = gce.disks.detect {|d| d.name == new_resource.name}
    raise "Source disk #{new_resource.name} not found" if source.nil?
    opts = {}
    opts[:writable] = new_resource.writable
    opts[:deviceName] = new_resource.device_name || new_resource.name
    opts[:boot] = new_resource.boot if new_resource.boot
    opts[:autoDelete] = new_resource.auto_delete
    converge_by("attach disk #{new_resource.name}") do
      gce.attach_disk(
        new_resource.instance_name,
        new_resource.zone_name,
        source.self_link,
        opts)
      Timeout::timeout(new_resource.timeout) do
        while true
          if disk_ready?(gce, new_resource.instance_name, opts[:device_name])
            Chef::Log.debug("Completed attaching disk #{new_resource.name}")
            break
          else
            Chef::Log.debug("Waiting for disk #{new_resource.name} to be attached")
            sleep 1
          end  
        end
      end
    end
  rescue Timeout::Error
    raise "Timed out waiting for disk attach after #{new_resource.timeout} seconds"
  end
end

action :detach do
  Chef::Log.debug("Attempting to detach disk #{new_resource.name}")
  unless disk_ready?(gce, new_resource.instance_name, new_resource.name) 
    raise "#{new_resource.name} not attached to #{new_resource.instance_name}"
  end
  converge_by("detach disk #{new_resource.name}") do
    gce.detach_disk(
      new_resource.instance_name,
      new_resource.zone,
      new_resource.name)
  end
  Chef::Log.debug("Completed detaching disk #{new_resource.name}")
end

private

def disk_ready?(connection, instance, disk)
  server = gce.servers.detect {|s| s.name == instance}
  disk = server.disks.detect {|d| d['device_name'] == disk}
  if disk == nil
    return false
  else
    return true
  end
end
