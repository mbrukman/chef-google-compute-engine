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

actions :create, :delete

# Google Compute Engine Credentials
attribute :client_email,            :kind_of => String, :required => true
attribute :key_location,            :kind_of => String, :required => true
attribute :project_id,              :kind_of => String, :required => true

attribute :name,                    :kind_of => String
attribute :network,                 :kind_of => String
attribute :allowed_protocol,        :kind_of => String, :default => "TCP", :equal_to => ["TCP", "UDP"]
attribute :allowed_ports,           :kind_of => Array, :default => Array.new
attribute :source_ranges,           :kind_of => Array, :default => ["0.0.0.0/0"]
attribute :source_tags,             :kind_of => Array, :default => Array.new
attribute :target_tags,             :kind_of => Array, :default => Array.new
attribute :timeout,                 :kind_of => Integer, :default => 60

def initialize(*args)
  super
  @action = :create
end
