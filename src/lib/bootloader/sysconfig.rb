require "yast"

module Bootloader
  # Represents sysconfig file for bootloader usually located in /etc/sysconfig/bootloader
  class Sysconfig
    include Yast::Logger
    AGENT_PATH = Yast::Path.new(".sysconfig.bootloader")
    ATTR_VALUE_MAPPING = {
      bootloader:  "LOADER_TYPE",
      secure_boot: "SECURE_BOOT"
    }

    # specifies bootloader in sysconfig
    attr_accessor :bootloader
    # boolean attribute if secure boot should be used
    attr_accessor :secure_boot

    def initialize(bootloader: nil, secure_boot: false)
      @sys_agent = AGENT_PATH
      @bootloader = bootloader
      @secure_boot = secure_boot
    end

    def self.from_system
      bootloader = Yast::SCR.Read(AGENT_PATH + "LOADER_TYPE")
      # propose secure boot always to true (bnc#872054), otherwise respect user choice
      secure_boot = Yast::SCR.Read(AGENT_PATH + "SECURE_BOOT") != "no"

      new(bootloader: bootloader, secure_boot: secure_boot)
    end

    # Specialized write before rpm install, that do not have switched SCR
    # and work on blank system
    def pre_write
      ensure_file_exists_in_target
      temporary_target_agent do
        write
      end
    end

    PROPOSED_COMMENTS = {
      bootloader:  "\n" \
        "## Path:\tSystem/Bootloader\n" \
        "## Description:\tBootloader configuration\n" \
        "## Type:\tlist(grub,grub2,grub2-efi,none)\n" \
        "## Default:\tgrub2\n" \
        "#\n" \
        "# Type of bootloader in use.\n" \
        "# For making the change effect run bootloader configuration tool\n" \
        "# and configure newly selected bootloader\n" \
        "#\n" \
        "#\n",

      secure_boot: "\n" \
        "## Path:\tSystem/Bootloader\n" \
        "## Description:\tBootloader configuration\n" \
        "## Type:\tyesno\n" \
        "## Default:\t\"no\"\n" \
        "#\n" \
        "# Enable UEFI Secure Boot support\n" \
        "# This setting is only relevant to UEFI which supports UEFI. It won't\n" \
        "# take effect on any other firmware type.\n" \
        "#\n" \
        "#\n"
    }

    def write
      log.info "Saving /etc/sysconfig/bootloader for #{bootloader}"

      write_option(:bootloader, bootloader)

      sb = secure_boot ? "yes" : "no"
      write_option(:secure_boot, sb)

      # flush write
      Yast::SCR.Write(sys_agent, nil)

      nil
    end

  private

    attr_accessor :sys_agent

    def destdir
      return @destdir if @destdir

      Yast.import "Installation"

      @destdir = Yast::Installation.destdir
    end

    def ensure_file_exists_in_target
      return if File.exist?(File.join(destdir, "/etc/sysconfig"))

      Yast::WFM.Execute(Yast::Path.new(".local.mkdir"),
        File.join(destdir, "/etc/sysconfig")
      )
      Yast::WFM.Execute(Yast::Path.new(".local.bash"),
        "touch #{destdir}/etc/sysconfig/bootloader"
      )
    end

    def temporary_target_agent(&block)
      old_agent = sys_agent
      @sys_agent = Yast::Path.new(".target.sysconfig.bootloader")

      target_sysconfig_path = "#{destdir}/etc/sysconfig/bootloader"
      # Register new agent to temporary path. It register same agent as in
      # scrconf but to different path and it also touch different file
      # For more info see documentation of {SCR}
      Yast::SCR.RegisterAgent(
        @sys_agent,
        Yast::Term.new(:ag_ini,
          Yast::Term.new(:SysConfigFile, target_sysconfig_path))
      )

      block.call
    ensure
      Yast::SCR.UnregisterAgent(@sys_agent)
      @sys_agent = old_agent
    end

    def write_option(option, value)
      file_path_option = sys_agent + ATTR_VALUE_MAPPING[option]
      comment_path = file_path_option + "comment"
      comment_exist = Yast::SCR.Read(comment_path)

      # write value of option
      Yast::SCR.Write(file_path_option, value)

      # write comment of option only if it doesn't exist
      return if comment_exist

      Yast::SCR.Write(comment_path, PROPOSED_COMMENTS[option])
    end
  end
end
