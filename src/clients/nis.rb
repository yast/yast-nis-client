# ------------------------------------------------------------------------------
# Copyright (c) 2006-2012 Novell, Inc. All Rights Reserved.
#
#
# This program is free software; you can redistribute it and/or modify it under
# the terms of version 2 of the GNU General Public License as published by the
# Free Software Foundation.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along with
# this program; if not, contact Novell, Inc.
#
# To contact Novell about this file by physical or electronic mail, you may find
# current contact information at www.novell.com.
# ------------------------------------------------------------------------------

# File:
#   nis.ycp
#
# Module:
#   Configuration of nis
#
# Summary:
#   Main file
#
# Authors:
#   Dan Vesely <dan@suse.cz>
#   Martin Vidner <mvidner@suse.cz>
#
# $Id$
#
# Configure ypclient via running SuSEconfig
# Modify: /etc/rc.config
#

# **
# <h3>Configuration of the nis</h3>

# @param flag "<b>screenshots</b>"<br>
#  <dl>
#   <dd>uses faked data (see Nis::Fake), enables running the module
#    as non-root. (Uses Mode::screen_shot().)
#  </dl>
module Yast
  class NisClient < Client
    def main
      Yast.import "UI"
      textdomain "nis"

      Yast.import "CommandLine"
      Yast.import "Nis"
      Yast.import "PackageSystem"
      Yast.import "RichText"

      Yast.include self, "nis/ui.rb"

      @ret = :auto

      if !PackageSystem.CheckAndInstallPackagesInteractive(
        Nis.required_packages
      )
        return deep_copy(@ret)
      end

      # the command line description map
      @cmdline = {
        "id"         => "nis",
        # translators: command line help text for Ldap client module
        "help"       => _(
          "NIS client configuration module."
        ),
        "guihandler" => fun_ref(method(:NormalSequence), "symbol ()"),
        "initialize" => fun_ref(Nis.method(:Read), "boolean ()"),
        "finish"     => fun_ref(Nis.method(:Write), "boolean ()"),
        "actions"    => {
          "enable"    => {
            "handler" => fun_ref(method(:NisEnableHandler), "boolean (map)"),
            # command line help text for 'enable' action
            "help"    => _(
              "Enable your machine as NIS client"
            )
          },
          "disable"   => {
            "handler" => fun_ref(method(:NisDisableHandler), "boolean (map)"),
            # command line help text for 'disable' action
            "help"    => _(
              "Disable the NIS client"
            )
          },
          "summary"   => {
            "handler" => fun_ref(method(:NisSummaryHandler), "boolean (map)"),
            # command line help text for 'summary' action
            "help"    => _(
              "Configuration summary of NIS client"
            )
          },
          "configure" => {
            # FIXME: "set" alias?
            "handler" => fun_ref(
              method(:NisChangeConfiguration),
              "boolean (map)"
            ),
            # command line help text for 'configure' action
            "help"    => _(
              "Change the global settings of NIS client"
            )
          },
          "find"      => {
            "handler" => fun_ref(method(:NisFindServers), "boolean (map)"),
            # command line help text for 'find' action
            "help"    => _(
              "Show available NIS servers for given domain"
            )
          }
        },
        "options"    => {
          "server"      => {
            # command line help text for the 'server' option
            "help" => _(
              "NIS server name or address"
            ),
            "type" => "string"
          },
          "domain"      => {
            # command line help text for the 'domain' option
            "help" => _(
              "NIS domain"
            ),
            "type" => "string"
          },
          "automounter" => {
            # help text for the 'automounter' option
            "help"     => _(
              "Start or stop automounter"
            ),
            "type"     => "enum",
            "typespec" => ["yes", "no"]
          },
          "broadcast"   => {
            # help text for the 'broadcast' option
            "help"     => _(
              "Set or unset broadcast search"
            ),
            "type"     => "enum",
            "typespec" => ["yes", "no"]
          }
        },
        "mappings"   =>
                        # TODO: more domains?
                        # YPBIND_OPTIONS: delimiter??
                        {
                          "enable"    => ["server", "domain", "automounter", "broadcast"],
                          "disable"   => [],
                          "summary"   => [],
                          "configure" => ["server", "domain", "automounter", "broadcast"],
                          "find"      => ["domain"]
                        }
      }

      @ret = CommandLine.Run(@cmdline)
      deep_copy(@ret)
    end

    # --------------------------------------------------------------------------
    # --------------------------------- cmd-line handlers

    # Change basic configuration of NIS client
    # @param [Hash] options  a list of parameters passed as args
    # @return [Boolean] true on success
    def NisChangeConfiguration(options)
      options = deep_copy(options)
      ret = false
      server = Ops.get_string(options, "server", "")
      if server != ""
        Nis.SetServers(server)
        ret = true
      end
      domain = Ops.get_string(options, "domain", "")
      if domain != ""
        Nis.SetDomain(domain)
        ret = true if Nis.DomainChanged
      end
      if Ops.get_string(options, "automounter", "") == "yes" &&
          !Nis._start_autofs
        Nis._start_autofs = true
        ret = true
      end
      if Ops.get_string(options, "automounter", "") == "no" && Nis._start_autofs
        Nis._start_autofs = false
        ret = true
      end
      if Ops.get_string(options, "broadcast", "") == "yes" &&
          !Nis.global_broadcast
        Nis.global_broadcast = true
        ret = true
      end
      if Ops.get_string(options, "broadcast", "") == "no" &&
          Nis.global_broadcast
        Nis.global_broadcast = false
        ret = true
      end
      ret
    end

    # Enable the NIS client
    # @param [Hash] options  a list of parameters passed as args
    # @return [Boolean] true on success
    def NisEnableHandler(options)
      options = deep_copy(options)
      NisChangeConfiguration(options)
      Nis.start = true
      # if (Nis::GetDomain () == "" || Nis::GetServers () == "")
      # Nis::dhcp_wanted  = true;
      true
    end

    # Disable the NIS client
    # @param [Hash] options  a list of parameters passed as args
    # @return [Boolean] true on success
    def NisDisableHandler(_options)
      Nis.start = false
      true
    end

    # Look for NIS servers in given domain and print them on stdout
    # @param [Hash] options  a list of parameters passed as args
    # @return [Boolean] true on success
    def NisFindServers(options)
      options = deep_copy(options)
      domain = Ops.get_string(options, "domain", "")
      domain = Nis.GetDomain if domain == ""
      Builtins.foreach(
        Convert.convert(
          SCR.Read(Builtins.add(path(".net.ypserv.find"), domain)),
          from: "any",
          to:   "list <string>"
        )
      ) { |server| CommandLine.Print(server) }
      false
    end

    # Print summary of basic options
    # @return [Boolean] false
    def NisSummaryHandler(_options)
      CommandLine.Print(
        RichText.Rich2Plain(
          Ops.add(
            Ops.add("<br>", Nis.ShortSummary),
            Nis.BrItem(
              _("Automounter enabled"),
              Nis._start_autofs ? _("Yes") : _("No")
            )
          )
        )
      )

      false # do not call Write...
    end
  end
end

Yast::NisClient.new.main
