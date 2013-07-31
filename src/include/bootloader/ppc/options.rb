# encoding: utf-8

# File:
#      modules/BootPOWERLILO.ycp
#
# Module:
#      Bootloader installation and configuration
#
# Summary:
#      Module containing specific functions for POWERLILO configuration
#      and installation
#
# Authors:
#      Jiri Srain <jsrain@suse.cz>
#      Joachim Plack <jplack@suse.de>
#      Olaf Dabrunz <od@suse.de>
#      Philipp Thomas <pth@suse.de>
#
# $Id$
#
module Yast
  module BootloaderPpcOptionsInclude
    def initialize_bootloader_ppc_options(include_target)
      textdomain "bootloader"

      Yast.import "Label"
      Yast.import "BootCommon"
      Yast.import "Arch"

      Yast.include include_target, "bootloader/ppc/helps.rb"
    end

    def InitDuplicatePartition(widget)
      devices = deep_copy(@prep_boot_partitions)
      if Builtins.size(devices) != 0
        UI.ChangeWidget(Id("clone"), :Items, devices)
      end
      UI.ChangeWidget(
        Id("clone"),
        :Value,
        Ops.get(BootCommon.globals, "clone", "")
      )

      nil
    end

    def StoreDuplicatePartition(widget, event)
      event = deep_copy(event)
      Ops.set(
        BootCommon.globals,
        "clone",
        Ops.get(
          Builtins.splitstring(
            Convert.to_string(UI.QueryWidget(Id("clone"), :Value)),
            " "
          ),
          0,
          ""
        )
      )

      nil
    end


    def DuplicatePartition
      {
        "widget" => :combobox,
        "label"  => _("Partition for Boot Loader &Duplication"),
        "items"  => [""],
        "opt"    => [:editable, :hstretch],
        "help"   => Ops.get(@ppc_help_messages, "clone", ""),
        "init"   => fun_ref(method(:InitDuplicatePartition), "void (string)"),
        "store"  => fun_ref(
          method(:StoreDuplicatePartition),
          "void (string, map)"
        )
      }
    end

    def InitBootPMAC(widget)
      devices = deep_copy(@pmac_boot_partitions)
      if Builtins.size(devices) != 0
        UI.ChangeWidget(Id("boot_pmac_custom"), :Items, devices)
      end
      UI.ChangeWidget(
        Id("boot_pmac_custom"),
        :Value,
        Ops.get(BootCommon.globals, "boot_pmac_custom", "")
      )

      nil
    end

    def StoreBootPMAC(widget, event)
      event = deep_copy(event)
      Ops.set(
        BootCommon.globals,
        "boot_pmac_custom",
        Ops.get(
          Builtins.splitstring(
            Convert.to_string(UI.QueryWidget(Id("boot_pmac_custom"), :Value)),
            " "
          ),
          0,
          ""
        )
      )

      nil
    end

    def BootPMAC
      {
        "widget"        => :custom,
        "custom_widget" => VBox(
          Frame(
            _("Boot Loader Location"),
            VBox(
              Left(
                HBox(
                  HSpacing(1),
                  VBox(
                    Left(
                      ComboBox(
                        Id("boot_pmac_custom"),
                        Opt(:editable, :hstretch),
                        _("HFS Boot &Partition"),
                        [""]
                      )
                    )
                  )
                )
              )
            )
          )
        ),
        "help"          => Ops.get(@ppc_help_messages, "boot_pmac_custom", ""),
        "init"          => fun_ref(method(:InitBootPMAC), "void (string)"),
        "store"         => fun_ref(method(:StoreBootPMAC), "void (string, map)")
      }
    end


    def InitBootCHRP(widget)
      devices = deep_copy(@prep_boot_partitions)
      if Builtins.size(devices) != 0
        UI.ChangeWidget(Id("boot_chrp_custom"), :Items, devices)
      end

      UI.ChangeWidget(
        Id("boot_chrp_custom"),
        :Value,
        Ops.get(BootCommon.globals, "boot_chrp_custom", "")
      )

      nil
    end

    def StoreBootCHRP(widget, event)
      event = deep_copy(event)
      Ops.set(
        BootCommon.globals,
        "boot_chrp_custom",
        Ops.get(
          Builtins.splitstring(
            Convert.to_string(UI.QueryWidget(Id("boot_chrp_custom"), :Value)),
            " "
          ),
          0,
          ""
        )
      )

      nil
    end


    def BootCHRP
      {
        "widget"        => :custom,
        "custom_widget" => VBox(
          Frame(
            _("Boot Loader Location"),
            VBox(
              Left(
                HBox(
                  HSpacing(1),
                  VBox(
                    Left(
                      ComboBox(
                        Id("boot_chrp_custom"),
                        Opt(:editable, :hstretch),
                        _("&PReP or FAT Partition"),
                        [""]
                      )
                    )
                  )
                )
              )
            )
          )
        ),
        "help"          => Ops.get(@ppc_help_messages, "boot_chrp_custom", ""),
        "init"          => fun_ref(method(:InitBootCHRP), "void (string)"),
        "store"         => fun_ref(method(:StoreBootCHRP), "void (string, map)")
      }
    end


    def InitBootPReP(widget)
      devices = deep_copy(@prep_boot_partitions)
      if Builtins.size(devices) != 0
        UI.ChangeWidget(Id("boot_prep_custom"), :Items, devices)
      end

      UI.ChangeWidget(
        Id("boot_prep_custom"),
        :Value,
        Ops.get(BootCommon.globals, "boot_prep_custom", "")
      )

      nil
    end

    def StoreBootPReP(widget, event)
      event = deep_copy(event)
      Ops.set(
        BootCommon.globals,
        "boot_prep_custom",
        Ops.get(
          Builtins.splitstring(
            Convert.to_string(UI.QueryWidget(Id("boot_prep_custom"), :Value)),
            " "
          ),
          0,
          ""
        )
      )

      nil
    end


    def BootPReP
      {
        "widget"        => :custom,
        "custom_widget" => VBox(
          Frame(
            _("Boot Loader Location"),
            VBox(
              Left(
                HBox(
                  HSpacing(1),
                  VBox(
                    Left(
                      ComboBox(
                        Id("boot_prep_custom"),
                        Opt(:editable, :hstretch),
                        _("&PReP partitions"),
                        [""]
                      )
                    )
                  )
                )
              )
            )
          )
        ),
        "help"          => Ops.get(@ppc_help_messages, "boot_prep_custom", ""),
        "init"          => fun_ref(method(:InitBootPReP), "void (string)"),
        "store"         => fun_ref(method(:StoreBootPReP), "void (string, map)")
      }
    end


    def InitBootISeries(widget)
      devices = deep_copy(@prep_boot_partitions)
      if Builtins.size(devices) != 0
        UI.ChangeWidget(Id("boot_iseries_custom"), :Items, devices)
      end

      if Ops.get(BootCommon.globals, "boot_iseries_custom", "") == ""
        UI.ChangeWidget(Id("enable_iseries"), :Value, false)
        UI.ChangeWidget(Id("boot_iseries_custom"), :Enabled, false)
      else
        UI.ChangeWidget(Id("enable_iseries"), :Value, true)
        UI.ChangeWidget(Id("boot_iseries_custom"), :Enabled, true)
        UI.ChangeWidget(
          Id("boot_iseries_custom"),
          :Value,
          Ops.get(BootCommon.globals, "boot_iseries_custom", "")
        )
      end

      if Ops.get(BootCommon.globals, "boot_slot", "") != ""
        UI.ChangeWidget(
          Id("boot_slot"),
          :Value,
          Ops.get(BootCommon.globals, "boot_slot", "")
        )
      end

      if Ops.get(BootCommon.globals, "boot_file", "") != ""
        UI.ChangeWidget(
          Id("boot_file"),
          :Value,
          Ops.get(BootCommon.globals, "boot_file", "")
        )
      end

      nil
    end

    def HandleBootISeries(key, event)
      event = deep_copy(event)
      ret = Ops.get(event, "ID")
      if ret == "enable_iseries"
        UI.ChangeWidget(
          Id("boot_iseries_custom"),
          :Enabled,
          Convert.to_boolean(UI.QueryWidget(Id("enable_iseries"), :Value))
        )
      end

      if ret == "boot_file_browse"
        current = Convert.to_string(UI.QueryWidget(Id("boot_file"), :Value))
        # file open popup caption
        current = UI.AskForExistingFile(current, "*", _("Select File"))
        UI.ChangeWidget(Id("boot_file"), :Value, current) if current != nil
      end
      nil
    end





    def StoreBootISeries(widget, event)
      event = deep_copy(event)
      if Convert.to_boolean(UI.QueryWidget(Id("enable_iseries"), :Value))
        Ops.set(
          BootCommon.globals,
          "boot_iseries_custom",
          Ops.get(
            Builtins.splitstring(
              Convert.to_string(
                UI.QueryWidget(Id("boot_iseries_custom"), :Value)
              ),
              " "
            ),
            0,
            ""
          )
        )
      else
        Ops.set(BootCommon.globals, "boot_iseries_custom", "")
      end

      Ops.set(
        BootCommon.globals,
        "boot_slot",
        Ops.get(
          Builtins.splitstring(
            Convert.to_string(UI.QueryWidget(Id("boot_slot"), :Value)),
            " "
          ),
          0,
          ""
        )
      )

      Ops.set(
        BootCommon.globals,
        "boot_file",
        Convert.to_string(UI.QueryWidget(Id("boot_file"), :Value))
      )

      nil
    end






    def BootISeries
      {
        "widget"        => :custom,
        "custom_widget" => VBox(
          Frame(
            _("Boot Loader Location"),
            VBox(
              Left(
                HBox(
                  HSpacing(1),
                  VBox(
                    Left(
                      CheckBox(
                        Id("enable_iseries"),
                        Opt(:notify),
                        _("&PReP Partition")
                      )
                    ),
                    Left(
                      ComboBox(
                        Id("boot_iseries_custom"),
                        Opt(:editable, :hstretch),
                        "",
                        [""]
                      )
                    ),
                    Left(
                      HBox(
                        Left(
                          InputField(
                            Id("boot_file"),
                            Opt(:hstretch),
                            _("Create Boot &Image in File")
                          )
                        ),
                        VBox(
                          Label(""),
                          PushButton(
                            Id("boot_file_browse"),
                            Opt(:notify),
                            Label.BrowseButton
                          )
                        )
                      )
                    ),
                    Left(
                      ComboBox(
                        Id("boot_slot"),
                        _("&Write to Boot Slot"),
                        ["", "A", "B", "C", "D"]
                      )
                    )
                  )
                )
              )
            )
          )
        ),
        "help"          => Ops.get(
          @ppc_help_messages,
          "boot_iseries_custom",
          ""
        ),
        "init"          => fun_ref(method(:InitBootISeries), "void (string)"),
        "handle"        => fun_ref(
          method(:HandleBootISeries),
          "symbol (string, map)"
        ),
        "store"         => fun_ref(
          method(:StoreBootISeries),
          "void (string, map)"
        )
      }
    end


    # Get the globals dialog tabs description
    # @return a map the description of the tabs
    def PPCOptions
      ppc_specific =
        # end PMAC
        {
          "append"        => CommonInputFieldWidget(
            _("Global Append &String of Options to Kernel Command Line"),
            Ops.get(@ppc_help_messages, "append", "")
          ),
          "initrd"        => CommonInputFieldBrowseWidget(
            _("Nam&e of Default Initrd File"),
            Ops.get(@ppc_help_messages, "initrd", ""),
            "initrd"
          ),
          "root"          => CommonInputFieldWidget(
            _("Set Default &Root Filesystem"),
            Ops.get(@ppc_help_messages, "root", "")
          ),
          "activate"      => CommonCheckboxWidget(
            _("Change Boot Device in &NV-RAM"),
            Ops.get(@ppc_help_messages, "activate", "")
          ),
          # CHRP
          "force_fat"     => CommonCheckboxWidget(
            _("&Always Boot from FAT Partition"),
            Ops.get(@ppc_help_messages, "force_fat", "")
          ),
          "force"         => CommonCheckboxWidget(
            _("&Install Boot Loader Even on Errors"),
            Ops.get(@ppc_help_messages, "force", "")
          ),
          "clone"         => DuplicatePartition(),
          # end CHRP

          # PREP also for PMAC
          "bootfolder"    => CommonInputFieldWidget(
            _("Boot &Folder Path"),
            Ops.get(@ppc_help_messages, "bootfolder", "")
          ),
          # end PREP

          # PMAC
          "no_os_chooser" => CommonCheckboxWidget(
            _("&Do not Use OS-chooser"),
            Ops.get(@ppc_help_messages, "no_os_chooser", "")
          ),
          "macos_timeout" => CommonIntFieldWidget(
            _("&Timeout in Seconds for MacOS/Linux"),
            Ops.get(@ppc_help_messages, "macos_timeout", ""),
            0,
            60
          )
        }
      Convert.convert(
        Builtins.union(ppc_specific, CommonOptions()),
        :from => "map",
        :to   => "map <string, map <string, any>>"
      )
    end
  end
end
