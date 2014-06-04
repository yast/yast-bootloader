# encoding: utf-8

# File:
#      modules/GfxMenu.ycp
#
# Module:
#      Bootloader installation and configuration
#
# Summary:
#      Routines to maintain translations in the graphical bootloader menu
#
# Authors:
#      Jiri Srain <jsrain@suse.cz>
#      Olaf Dabrunz <od@suse.de>
#
# $Id$
#
require "yast"

module Yast
  class GfxMenuClass < Module
    def main

      textdomain "bootloader"

      Yast.import "Mode"

      # FATE#305403: Bootloader beep configuration
      # enable/disable sounds signal during boot
      @enable_sound_signals = false
    end

    # FATE#305403: Bootloader beep configuration
    # Read status of acoustic signals
    # set global variable enable_sound_signals
    #
    def ReadStatusAcousticSignal
      ret = -1 # off

      command = "gfxboot --show-config | grep beep="
      out = Convert.to_map(SCR.Execute(path(".target.bash_output"), command))

      Builtins.y2milestone("Comand: %1 return: %2", command, out)
      if Ops.get_integer(out, "exit", -1) == 0
        result = Ops.get_string(out, "stdout", "")
        l_result = Builtins.splitstring(result, "\n")
        if Ops.get(l_result, 1, "") == "beep=1"
          ret = 1
        else
          ret = 0
        end
      else
        Builtins.y2error("Calling command: %1 failed", command)
      end
      if ret == 1
        @enable_sound_signals = true
      else
        @enable_sound_signals = false
      end

      Builtins.y2milestone(
        "Status of acoustic signals is (on==true/off==false): %1",
        @enable_sound_signals
      )

      nil
    end


    # FATE#305403: Bootloader beep configuration
    # Write settings for acoustic signals
    #
    # @param boolean true -> enable acoustic signals or disable
    def WriteAcousticSignal(enable)
      command = "gfxboot --change-config boot::beep=0"
      if enable
        Builtins.y2milestone("Enable acoustic signals for boot menu")
        command = "gfxboot --change-config boot::beep=1"
      else
        Builtins.y2milestone("Disable acoustic signals for boot menu")
      end
      ret = Convert.to_map(SCR.Execute(path(".target.bash_output"), command))
      Builtins.y2milestone("Result of command: %1 result: %2", command, ret)

      nil
    end


    # Update graphical bootloader to contain translations for section labels in
    # the currently selected installation language (set in
    # /etc/sysconfig/language, RC_LANG)
    # And make the selected installation language default
    # @param [String] loader string bootloader type
    # @return [Boolean] true on success
    def UpdateGfxMenuContents(loader)
      Builtins.y2milestone("Updating GFX boot menu")

      # FATE#305403: Bootloader beep configuration
      WriteAcousticSignal(@enable_sound_signals)
      # if the boot menu does not exist, return without updating it
      return true if SCR.Read(path(".target.size"), "/boot/message") == -1
      if SCR.Read(path(".target.size"), "/etc/sysconfig/bootsplash") == -1
        return true
      end

      # get a list containing the system default language and the installed languages
      # get the current language
      main_lang = Convert.to_string(
        SCR.Read(path(".sysconfig.language.RC_LANG"))
      )
      langs = Convert.to_string(
        SCR.Read(path(".sysconfig.language.INSTALLED_LANGUAGES"))
      )
      langs = "" if langs == nil
      languages = Builtins.splitstring(langs, ",")
      languages = Builtins.prepend(languages, main_lang)
      languages = Builtins.filter(languages) { |l| l != nil }
      # if no languages are installed and no main language is defined, we can do
      # nothing: simply return
      return true if Builtins.size(languages) == 0

      # if no boot theme is defined, we cannot create the GfxMenu: just leave
      boot_theme = Convert.to_string(
        SCR.Read(path(".sysconfig.bootsplash.THEME"))
      )
      return true if boot_theme == nil


      # in the list of the system default language and the installed languages
      # find the subset that is supported by either a help text or a translation
      # file (for the GUI messages) or both
      # results:
      # selected    -- list of supported languages (both long form (de_DE) and short form (de))
      # lang_params -- string of supported languages (both long form (de_DE) and short form (de))

      # get names of available languages
      data_dir = Builtins.sformat(
        "/etc/bootsplash/themes/%1/bootloader",
        boot_theme
      )
      files = Convert.convert(
        SCR.Read(path(".target.dir"), data_dir),
        :from => "any",
        :to   => "list <string>"
      )
      helps = Builtins.filter(files) { |f| Builtins.regexpmatch(f, '\.hlp$') }
      texts = Builtins.filter(files) { |f| Builtins.regexpmatch(f, '\.tr$') }
      helps = Builtins.maplist(helps) { |h| Builtins.substring(h, 0, 2) }
      texts = Builtins.maplist(texts) { |t| Builtins.substring(t, 0, 2) }
      Builtins.y2milestone("Texts available for %1", Builtins.sort(texts))
      Builtins.y2milestone("Helps available for %1", Builtins.sort(helps))

      tmpdir = Convert.to_string(SCR.Read(path(".target.tmpdir")))
      lang_params = ""
      lang_supported = true

      selected = []
      Builtins.foreach(languages) do |lang|
        l = Builtins.splitstring(lang, ".")
        lang = Ops.get(l, 0, "")
        Builtins.y2milestone("Selected language for booting menu: %1", lang)
        l = Builtins.splitstring(lang, "_")
        lang_short = Ops.get(l, 0, "")
        # check if lang is supported by a help text and/or a GUI message
        # translation file
        if !(Builtins.contains(helps, lang_short) ||
            Builtins.contains(texts, lang_short))
          Builtins.y2milestone(
            "Language %1 is not supported by gfxmenu",
            lang_short
          )
          # rather avoid all translations; non-supported characters don't show
          # in the future, the menu should be translated into selected language,
          # not only into the system language
          lang_supported = false
        elsif !(Builtins.contains(selected, lang) ||
            Builtins.contains(selected, lang_short))
          lang_params = Builtins.sformat(
            "%1 %2 %3",
            lang_params,
            lang,
            lang_short
          )
          selected = Builtins.add(selected, lang)
          selected = Builtins.add(selected, lang_short)
        end
      end

      # do not create translation of section (bnc#875819)
      trans_str = ""
      SCR.Write(path(".target.string"), trans_file, trans_str)
      lang_params = "en_EN en" if lang_params == ""

      # update the boot message (/boot/message cpio archive) with menu entry
      # translation file (trans_file) and translation files for help texts and
      # UI texts
      #  - currently (2006/09) update_gfxmenu includes the hlp and tr files only
      #    for the first language (e.g. "de_DE de") from lang_params, the others
      #    are ignored
      #  - tr and hlp files that match the long language name ("de_DE") are
      #    preferred over files that contain only the short language name
      #  - English ("en") is always included in the list of selectable
      #    languages, and the English tr and hlp files are never removed from
      #    the message archive
      command = Builtins.sformat(
        "/usr/lib/YaST2/bin/update_gfxmenu %1 %2 %3 %4",
        tmpdir,
        data_dir,
        trans_file,
        lang_params
      )

      Builtins.y2milestone("Running command %1", command)
      ret = Convert.to_map(SCR.Execute(path(".target.bash_output"), command))
      Builtins.y2milestone("GFXMenu update result: %1", ret)
      Ops.get_integer(ret, "exit", 0) == 0
    end

    # Updates GFX menu without requiring any information, reads loader type
    # from sysconfig
    # @return [Boolean] true on success
    def Update
      loader = Convert.to_string(
        SCR.Read(path(".sysconfig.bootloader.LOADER_TYPE"))
      )
      return UpdateGfxMenuContents(loader)
    end

    publish :variable => :enable_sound_signals, :type => "boolean"
    publish :function => :ReadStatusAcousticSignal, :type => "void ()"
    publish :function => :UpdateGfxMenuContents, :type => "boolean (string)"
    publish :function => :Update, :type => "boolean ()"
  end

  GfxMenu = GfxMenuClass.new
  GfxMenu.main
end
