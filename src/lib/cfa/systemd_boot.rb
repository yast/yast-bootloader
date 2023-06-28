# frozen_string_literal: true

# Copyright (c) [2023] SUSE LLC
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

require "yast"
require "cfa/base_model"
require "yast2/target_file"
require "yast2/execute"

module CFA
  # CFA based class to handle systemd-boot configuration file
  #
  # @example Reading a value
  #   file = CFA::SystemdBoot.new
  #   file.load
  #   file.menue_timeout #=> 10
  #
  # @example Writing a value
  #   file = CFA::SystemdBoot.new
  #   file.menue_timeout = 5
  #   file.save
  #
  # @example Loading shortcut
  #   file = CFA::SystemdBoot.load
  #   file.menue_timeout #=> 10
  class SystemdBoot < BaseModel
    extend Yast::Logger
    include Yast::Logger

    attributes(
      menue_timeout: "timeout",
      console_mode:  "console_mode",
      default:       "default"
    )

    # Instantiates and loads a file when possible
    #
    # This method is basically a shortcut to instantiate and load the content in just one call.
    #
    # @param file_handler [#read,#write] something able to read/write a string (like File)
    # @param file_path    [String] File path
    # @return [SystemdBoot] File with the already loaded content
    def self.load(file_handler: Yast::TargetFile, file_path: PATH)
      file = new(file_path: file_path, file_handler: file_handler)
      file.tap(&:load)
    rescue Errno::ENOENT
      log.info("#{file_path} couldn't be loaded. Probably the file does not exist yet.")

      file
    end

    # Constructor
    #
    # @param file_handler [#read,#write] something able to read/write a string (like File)
    # @param file_path    [String] File path
    #
    # @see CFA::BaseModel#initialize
    def initialize(file_handler: Yast::TargetFile, file_path: PATH)
      super(AugeasParser.new(LENS), file_path, file_handler: file_handler)
    end

    def save
      directory = File.dirname(@file_path)
      if !Yast::FileUtils.IsDirectory(directory)
        Yast::Execute.on_target("/usr/bin/mkdir", "--parents",
          directory)
      end
      super
    rescue Errno::EACCES
      log.info("Permission denied when writting to #{@file_path}")
      false
    end

    # Default path to the systemd-boot config file
    PATH = "/boot/efi/loader/loader.conf"
    private_constant :PATH

    # The lens to be used by Augeas parser
    #
    LENS = "spacevars.lns"
    private_constant :LENS
  end
end
