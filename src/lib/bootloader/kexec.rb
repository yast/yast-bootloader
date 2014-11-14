require "yast"

module Bootloader
  class Kexec
    include Yast::Logger

    def initialize
      Yast.import "Arch"
      Yast.import "Directory"
      Yast.import "Installation"
      Yast.import "Mode"
      Yast.import "ProductFeatures"
    end

    def prepare_environment
      log.info "CopyKernelInird: start copy kernel and inird"

      if Yast::Mode.live_installation
        log.info "Running live_installation without using kexec"
        return false
      end

      if !Yast::ProductFeatures.GetBooleanFeature("globals", "kexec_reboot")
        log.info "Option kexec_reboot is false. kexec will not be used."
        return false
      end

      # check architecture for using kexec instead of reboot
      if Yast::Arch.ppc || Yast::Arch.s390
        log.info "Skip using of kexec on this architecture"
        return false
      end

      log.info "CopyKernelInird::bios_data = #{bios_data}"

      if IsVirtualBox(bios_data)
        log.info "Installation run on VirtualBox, skip kexec loading"
        return false
      end

      if IsHyperV(bios_data)
        log.info "Installation run on HyperV, skip kexec loading"
        return false
      end

      # create directory /var/lib/YaST2
      Yast::WFM.Execute(Yast::Path.new(".local.mkdir"), "/var/lib/YaST2")

      cmd = Yast::Builtins.sformat(
        "/bin/cp -L %1/%2 %1/%3 %4",
        Yast::Installation.destdir,
        "vmlinuz",
        "initrd",
        Yast::Directory.vardir
      )

      log.info "Command for copy: #{cmd}"
      out = Yast::WFM.Execute(Yast::Path.new(".local.bash_output"), cmd)
      if out["exit"] != 0
        log.error "Copy kernel and initrd failed, output: #{out}"
        return false
      end

      true
    end

  private

    # Get entry from DMI data returned by .probe.bios.
    #
    # @param [Array<Hash>] bios_data: result of SCR::Read(.probe.bios)
    # @param [String] section: section name
    # @param [String] key: key in section
    # @return [String]: entry
    def DMIRead(bios_data, section, key)
      smbios = bios_data.fetch(0, {}).fetch("smbios", [])

      result = smbios.find { |x| x["type"] == section }
      result = result[key] if result
      result ||= ""

      log.info "Bootloader::DMIRead(#{section}, #{key}) = #{result}"

      result
    end


    # Check if we run in a vbox vm.
    #
    # @param [Array<Hash>] bios_data: result of SCR::Read(.probe.bios)
    # @return [Boolean]: true if yast runs in a vbox vm
    def IsVirtualBox(bios_data)
      r = DMIRead(bios_data, "sysinfo", "product") == "VirtualBox"

      log.info "Bootloader::IsVirtualBox = #{r}"

      r
    end


    # Check if we run in a hyperv vm.
    #
    # @param [Array<Hash>] bios_data: result of SCR::Read(.probe.bios)
    # @return [Boolean]: true if yast runs in a hyperv vm
    def IsHyperV(bios_data)
      r = DMIRead(bios_data, "sysinfo", "manufacturer") ==
        "Microsoft Corporation" &&
        DMIRead(bios_data, "sysinfo", "product") == "Virtual Machine"

      log.info "Bootloader::IsHyperV = #{r}"

      r
    end

    def bios_data
      @bios_data ||= Yast::SCR.Read(Yast::Path.new(".probe.bios"))
    end
  end
end
