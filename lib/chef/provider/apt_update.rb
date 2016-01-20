#
# Author:: Thom May (<thom@chef.io>)
# Copyright:: Copyright (c) 2016 Chef Software, Inc.
# License:: Apache License, Version 2.0
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
#

require "chef/resource/apt_update"

class Chef
  class Provider
    class AptUpdate < Chef::Provider
      provides :apt_update, os: "linux"

      def whyrun_supported?
        true
      end

      def load_current_resource
      end

      def do_update
        %w{/var/lib/apt/periodic /etc/apt/apt.conf.d}.each do |d|
          dir = Chef::Resource::Directory.new(d, run_context)
          dir.recursive(true)
          dir.run_action(:create_if_missing)
          new_resource.updated_by_last_action(true) if dir.updated_by_last_action?
        end
        config = Chef::Resource::File.new("/etc/apt/apt.conf.d/15update-stamp", run_context)
        config.content('APT::Update::Post-Invoke-Success {"touch /var/lib/apt/periodic/update-success-stamp 2>/dev/null || true";};')
        config.run_action(:create)
        new_resource.updated_by_last_action(true) if config.updated_by_last_action?
        shell_out!("apt-get -q update")
      end

      def action_periodic
        if !apt_up_to_date?
          converge_by "update new lists of packages" do
            do_update
          end
        end
      end

      def action_update
        converge_by "force update new lists of packages" do
          do_update
        end
      end

      private
      # Determines whether we need to run `apt-get update`
      #
      # @return [Boolean]
      def apt_up_to_date?
        ::File.exist?("/var/lib/apt/periodic/update-success-stamp") &&
          ::File.mtime("/var/lib/apt/periodic/update-success-stamp") > Time.now - new_resource.frequency
      end

    end
  end
end
