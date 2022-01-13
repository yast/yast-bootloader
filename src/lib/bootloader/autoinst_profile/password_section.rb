# frozen_string_literal: true

# Copyright (c) [2022] SUSE LLC
#
# All Rights Reserved.
#
# This program is free software; you can redistribute it and/or modify it
# under the terms of version 2 of the GNU General Public License as published
# by the Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
# FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
# more details.
#
# You should have received a copy of the GNU General Public License along
# with this program; if not, contact SUSE LLC.
#
# To contact SUSE LLC about this file by physical or electronic mail, you may
# find current contact information at www.suse.com.

require "installation/autoinst_profile/section_with_attributes"

module Bootloader
  module AutoinstProfile
    # This class represents an AutoYaST <password> section within a <global> one
    class PasswordSection < ::Installation::AutoinstProfile::SectionWithAttributes
      def self.attributes
        [
          { name: :value },
          { name: :encrypted },
          { name: :unrestricted }
        ]
      end

      define_attr_accessors

      # @!attribute value
      #   @return [String] password value

      # @!attribute encrypted
      #   @return [String,nil] if value attribute is encrypted it is set to "true".
      #     not encrypted in other cases

      # @!attribute unrestricted
      #   @return [String,nil] password is unrestricted if set to "false"
      #   @see Grub2Pwd#unrestricted
    end
  end
end
