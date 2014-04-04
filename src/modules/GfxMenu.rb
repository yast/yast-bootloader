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

    # Replace every match of given regular expression in a string with a
    # replacement string
    #
    # e.g. ReplaceRegexMatch( "abcdef12ef34gh000", "[0-9]+", "_A_" ) -> "abcdef_A_ef_A_gh_A_"
    #
    # @param [String] input string that may contain substrings matching regex
    # @param [String] regex regular expression to search for, must not contain brackets
    # @param [String] repl  string that replaces every substring matching the regex
    # @return [String] that has matches replaced
    def ReplaceRegexMatch(input, regex, repl)
      return "" if input == nil || Ops.less_than(Builtins.size(input), 1)
      rest = input
      output = ""
      if Builtins.regexpmatch(rest, regex)
        p = Builtins.regexppos(rest, regex)
        begin
          output = Ops.add(
            Ops.add(
              output,
              Builtins.substring(rest, 0, Ops.get_integer(p, 0, 0))
            ),
            repl
          )
          rest = Builtins.substring(
            rest,
            Ops.add(Ops.get_integer(p, 0, 0), Ops.get_integer(p, 1, 0))
          )
          p = Builtins.regexppos(rest, regex)
        end while Ops.greater_than(Builtins.size(p), 0)
      end
      Ops.add(output, rest)
    end

    # Create translated name of a section
    # @param [String] orig string original section name
    # @param [String] loader string bootloader type
    # @return translated section name
    def translateSectionTitle(orig, loader)
      #
      # FIXME: handling of bootloader-specific restrictions should be done
      # in perl-Bootloader
      #
      trans = {
        # entry of bootloader menu - only a-z, A-Z, 0-9, _ and blank space
        # are allowed, otherwise translartion won't be used
        # try to keep short, may be shortened due to bootloader limitations
        "linux"              => _(
          "Linux"
        ),
        # entry of bootloader menu - only a-z, A-Z, 0-9, _ and blank space
        # are allowed, otherwise translartion won't be used
        # try to keep short, may be shortened due to bootloader limitations
        "failsafe"           => _(
          "Failsafe"
        ),
        # entry of bootloader menu - only a-z, A-Z, 0-9, _ and blank space
        # are allowed, otherwise translartion won't be used
        # try to keep short, may be shortened due to bootloader limitations
        "floppy"             => _(
          "Floppy"
        ),
        # entry of bootloader menu - only a-z, A-Z, 0-9, _ and blank space
        # are allowed, otherwise translartion won't be used
        # try to keep short, may be shortened due to bootloader limitations
        "hard disk"          => _(
          "Hard Disk"
        ),
        # entry of bootloader menu - only a-z, A-Z, 0-9, _ and blank space
        # are allowed, otherwise translartion won't be used
        # try to keep short, may be shortened due to bootloader limitations
        "memtest86"          => _(
          "Memory Test"
        ),
        # entry of bootloader menu - only a-z, A-Z, 0-9, _ and blank space
        # are allowed, otherwise translartion won't be used
        # try to keep short, may be shortened due to bootloader limitations
        "original MBR"       => _(
          "MBR before Installation"
        ),
        # entry of bootloader menu - only a-z, A-Z, 0-9, _ and blank space
        # are allowed, otherwise translartion won't be used
        # try to keep short, may be shortened due to bootloader limitations
        "previous"           => _(
          "Previous Kernel"
        ),
        # entry of bootloader menu - only a-z, A-Z, 0-9, _ and blank space
        # are allowed, otherwise translartion won't be used
        # try to keep short, may be shortened due to bootloader limitations
        "Vendor diagnostics" => _(
          "Vendor Diagnostics"
        )
      }
      not_trans = {
        "linux"        => "Linux",
        "failsafe"     => "Failsafe",
        "floppy"       => "Floppy",
        "hard disk"    => "Hard Disk",
        "memtest86"    => "Memory Test",
        "original MBR" => "MBR before Installation",
        "windows"      => "Windows",
        "xen"          => "XEN"
      }
      translated = Ops.get_string(trans, orig, "\n") # not allowed character
      # not_translated version will be used
      filtered = Builtins.filterchars(
        translated,
        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890 _"
      )
      if Builtins.size(filtered) != Builtins.size(translated)
        Builtins.y2warning("Incorrect translation %1 -> %2", orig, translated)
        return Ops.get_string(not_trans, orig, orig)
      end
      if loader != "grub"
        # FIXME / FEATURE: At least for IA64, there is a two level boot
        # hierarchy (efibootmgr, elilo): the first level boot menu can be
        # used to select a partition (i.e. an installation), the second
        # level can be used to select a kernel/commandline set.
        # This may become an alternative setup for grub in the future
        # (requiring a separate menu.lst on an extra partition for the
        # first level, along with the changes in several parts of the
        # BootGRUB code for this).
        # AI: rw/od should discuss this with the grub maintainer and
        # create a feature for this.
        #
        # ATM, this is only available for IA64.
        # Thus, for "elilo", the second level string should remain
        # "linux", the product name already appears in the efi menu.
        if loader != "elilo" && orig == "linux"
          Yast.import "Product"
          product = Product.short_name
          prod_filtered = Builtins.filterchars(
            product,
            "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890 _."
          )
          filtered = prod_filtered if product == prod_filtered && product != " "
        end
        Builtins.y2milestone("adapting section title: %1", filtered)
        # label tag for lilo.conf has a restricted valid character set and
        # limited allowed string length
        cutoff = ""

        # Limit length to 11 characters, but keep it "nice"
        # 1. cut off linux- prefix if found
        if Ops.greater_than(Builtins.size(filtered), 11)
          cutoff = Builtins.regexpsub(filtered, "^[Ll][Ii][Nn][Uu][Xx]-", "")
          filtered = cutoff if cutoff != nil
        end

        while Ops.greater_than(Builtins.size(filtered), 11)
          # 2. cut off last word, break if no more found
          cutoff = Builtins.regexpsub(filtered, "^(.*) [^ ]*$", "\\1")
          Builtins.y2milestone("cutoff is: %1", cutoff)
          if cutoff == nil || Builtins.size(cutoff) == Builtins.size(filtered)
            break
          end
          filtered = cutoff
        end
        Builtins.y2milestone("section title without excess words: %1", filtered)

        # 3. last resort: cutoff excess characters
        filtered = Builtins.substring(filtered, 0, 11)
        Builtins.y2milestone("section title limited to 11 chars: %1", filtered)

        # 4. convert not allowed chars to "_"
        # (NOTE: this converts according to lilo requirements, ATM we do
        # not allow ".-" above already; so ATM this converts only " ")
        filtered = ReplaceRegexMatch(
          filtered,
          "[^abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890.-]",
          "_"
        )
        Builtins.y2milestone(
          "section title: filtered unallowed characters: %1",
          filtered
        )
      elsif Builtins.contains(["linux", "failsafe", "previous", "xen"], orig) &&
          !Mode.test
        # for bootloaders that support long section names, like grub:
        Yast.import "Product"
        product = Product.name
        prod_filtered = Builtins.filterchars(
          product,
          "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890 _."
        )
        if product != nil && product == prod_filtered && product != " " &&
            product != ""
          if orig == "linux"
            filtered = prod_filtered
          else
            filtered = Builtins.sformat("%1 -- %2", filtered, prod_filtered)
          end
        end
      end
      filtered
    end

    # Get translated section names, including diacritics
    # @param [String] loader string bootloader type
    # @return a map section names translations
    def getTranslationsToDiacritics(loader)
      trans = {
        # entry of bootloader menu - only ISO 8859-1, -2 and -15 characters
        # are allowed. Always remove the leading '_', its just to
        # be able to have translations with and without diacritics
        # please use diacritics here
        "linux"              => _(
          "_Linux"
        ),
        # entry of bootloader menu - only ISO 8859-1, -2 and -15 characters
        # are allowed. Always remove the leading '_', its just to
        # be able to have translations with and without diacritics
        # please use diacritics here
        "failsafe"           => _(
          "_Failsafe"
        ),
        # entry of bootloader menu - only ISO 8859-1, -2 and -15 characters
        # are allowed. Always remove the leading '_', its just to
        # be able to have translations with and without diacritics
        # please use diacritics here
        "floppy"             => _(
          "_Floppy"
        ),
        # entry of bootloader menu - only ISO 8859-1, -2 and -15 characters
        # are allowed. Always remove the leading '_', its just to
        # be able to have translations with and without diacritics
        # please use diacritics here
        "hard disk"          => _(
          "_Hard Disk"
        ),
        # entry of bootloader menu - only ISO 8859-1, -2 and -15 characters
        # are allowed. Always remove the leading '_', its just to
        # be able to have translations with and without diacritics
        # please use diacritics here
        "memtest86"          => _(
          "_Memory Test"
        ),
        # entry of bootloader menu - only ISO 8859-1, -2 and -15 characters
        # are allowed. Always remove the leading '_', its just to
        # be able to have translations with and without diacritics
        # please use diacritics here
        "original MBR"       => _(
          "_MBR before Installation"
        ),
        # entry of bootloader menu - only ISO 8859-1, -2 and -15 characters
        # are allowed. Always remove the leading '_', its just to
        # be able to have translations with and without diacritics
        # please use diacritics here
        "previous"           => _(
          "_Previous Kernel"
        ),
        # entry of bootloader menu - only ISO 8859-1, -2 and -15 characters
        # are allowed. Always remove the leading '_', its just to
        # be able to have translations with and without diacritics
        # please use diacritics here
        "Vendor diagnostics" => _(
          "_Vendor Diagnostics"
        ),
        "xen"                => "XEN"
      }
      # trans = filter (string k, string v, trans, {
      # 	    if (substring (v, 0, 1) == "_")
      # 	    {
      # 		y2warning ("Translation %1 contains leading underscore", v);
      # 		return false;
      # 	    }
      # 	    return true;
      # 	});
      trans = Builtins.mapmap(trans) do |k, v|
        v = Builtins.substring(v, 1) if Builtins.substring(v, 0, 1) == "_"
        { k => v }
      end
      ret = Builtins.mapmap(trans) do |k, v|
        il1 = translateSectionTitle(k, loader)
        if Builtins.contains(["linux", "failsafe", "previous", "xen"], k) &&
            !Mode.test
          Yast.import "Product"
          product = Product.name
          if product != " " && product != "" && product != nil
            if k == "linux"
              v = product
            else
              v = Builtins.sformat("%1 (%2)", product, v)
            end
          end
        end
        { il1 => v }
      end
      deep_copy(ret)
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

      # create translation map (in temp file) for the currently active language
      # for gettext (AFAICT), i.e. whatever is found in LANG or LC_MESSAGES --
      # this should be RC_LANG
      trans_file = Builtins.sformat("%1/boot_translations", tmpdir)
      trans_map = getTranslationsToDiacritics(loader)
      trans_list = Builtins.maplist(trans_map) do |k, v|
        Builtins.sformat("%1\n%2", k, v)
      end
      trans_str = Builtins.mergestring(trans_list, "\n")
      trans_str = Ops.add(trans_str, "\n")
      if !lang_supported
        Builtins.y2milestone("Avoiding providing bootloader menu translations")
        trans_str = ""
      end
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
    # from sysconfig, calls /sbin/lilo if LILO is being used directly
    # @return [Boolean] true on success
    def Update
      loader = Convert.to_string(
        SCR.Read(path(".sysconfig.bootloader.LOADER_TYPE"))
      )
      return false if !UpdateGfxMenuContents(loader)

      if loader == "lilo"
        out = Convert.to_map(
          SCR.Execute(path(".target.bash_output"), "/sbin/lilo")
        )
        if Ops.get_integer(out, "exit", 0) != 0
          Builtins.y2error("Output of /sbin/lilo: %1", out)
          return false
        end
      end
      true
    end

    publish :variable => :enable_sound_signals, :type => "boolean"
    publish :function => :ReplaceRegexMatch, :type => "string (string, string, string)"
    publish :function => :translateSectionTitle, :type => "string (string, string)"
    publish :function => :getTranslationsToDiacritics, :type => "map <string, string> (string)"
    publish :function => :ReadStatusAcousticSignal, :type => "void ()"
    publish :function => :UpdateGfxMenuContents, :type => "boolean (string)"
    publish :function => :Update, :type => "boolean ()"
  end

  GfxMenu = GfxMenuClass.new
  GfxMenu.main
end
