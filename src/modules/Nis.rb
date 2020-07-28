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
#   modules/Nis.ycp
#
# Module:
#   Configuration of NIS client
#
# Summary:
#   NIS client configuration data, I/O functions.
#
# Authors:
#   Jan Holesovsky <kendy@suse.cz>
#   Dan Vesely <dan@suse.cz>
#   Martin Vidner <mvidner@suse.cz>
#
# $Id$
#
require "yast"
require "y2firewall/firewalld"
require "shellwords"
Yast.import "Mode"

module Yast
  class NisClass < Module
    # @return [String] NIS client package name
    NIS_CLIENT_PACKAGE = "ypbind".freeze

    def main
      textdomain "nis"

      Yast.import "Address"
      Yast.import "Autologin"
      Yast.import "IP"
      Yast.import "Message"
      Yast.import "Nsswitch"
      Yast.import "Pam"
      Yast.import "Package"
      Yast.import "Progress"
      Yast.import "Report"
      Yast.import "Service"
      Yast.import "Summary"
      Yast.import "Wizard"

      # default value of settings modified
      @modified = false
      # Required packages for this module to operate
      #
      @required_packages = [NIS_CLIENT_PACKAGE]

      # Should ypbind be started at boot?
      # If not, other settings are not touched.
      @start = false

      # IP addresses of NIS servers.
      @servers = []

      # Broadcast for the default domain?
      # (New in ypbind-1.12)
      @default_broadcast = false

      # Servers for a multiple-domain configuration.
      # Keys are domains, values are lists of servers (strings).
      # The domains must be the same as for multidomain_broadcast
      # @see #multidomain_broadcast
      @multidomain_servers = {}

      # Servers for a multiple-domain configuration.
      # Whether a broadcast will be done if the servers don't respond.
      # Keys are domains, values are booleans.
      # The domains must be the same as for multidomain_servers
      # @see #multidomain_servers
      # @see #global_broadcast
      @multidomain_broadcast = {}

      # If this option is set, ypbind will ignore /etc/yp.conf and use
      # a broadcast call to find a NIS server in the local subnet. You
      # should avoid to use this, it is a big security risk.
      # @see #multidomain_broadcast
      # @see #default_broadcast
      @global_broadcast = false

      @slp_domain = {}

      # netconfig policy
      @policy = "auto"

      # which service mapper is used (rpcbind/portmap)
      @rpc_mapper = "rpcbind"

      @domain = ""
      @old_domain = nil
      @domain_changed = false

      @static_keylist = []

      # DHCP cooperation

      # #35654: if the server is running and sysconfig wants NIS data,
      # it's ok to FitIntoSingle
      @dhcpcd_running = false

      # If dhcp_wanted changes, we need to restart the DHCP client
      @dhcp_restart = false

      # The following four are from sysconfig/ypbind; the comments are
      # taken from there. The dialog help texts have "user friendlier"
      # descriptions.

      # If this option is set, ypbind will only bind to the loopback
      # interface and remote hosts cannot query it.
      @local_only = false

      # You should set this to "yes" if you have a NIS server in your
      # network, which binds only to high ports over 1024. Since this
      # is a security risk, you should consider to replace the NIS
      # server with another implementation.
      @broken_server = false

      # Extra options for ypbind. Here you can add options like
      # "-ypset", "-ypsetme", "-p port" or "-no-ping".
      @options = ""

      # If no, automounter will not be affected.
      @_autofs_allowed = true

      # Start automounter and import the settings from NIS. (Bug 6092)
      @_start_autofs = false

      # Output of "rcypbind start", if there was an error.
      # Read only.
      # This is currently used only in nis-server for its more advanced
      # error reporting. (Bug 14706)
      @YpbindErrors = ""

      # If the hostname resolution is done over NIS,
      # names cannot be used to specify servers.
      @hosts_by_nis = false

      # Using NIS and LDAP simultaneously is not supported (#36981).
      @users_by_ldap = false

      # ----------------------------------------------------------------

      # Has the configuration been changed?
      # Can be used as an argument to Popup::ReallyAbort
      @touched = false

      # ----------------------------------------------------------------

      # Read only, set by ProbePackages.
      # Use as an argument to DoInstallAndRemove
      @install_packages = []
    end

    # Function sets internal variable, which indicates, that any
    # settings were modified, to "true"
    def SetModified
      @modified = true

      nil
    end

    # Functions which returns if the settings were modified
    # @return [Boolean]  settings were modified
    def GetModified
      @modified
    end

    # @return Access the servers as a string
    def GetServers
      Builtins.mergestring(@servers, " ")
    end

    # Set the servers from a string
    # @param [String] servers_s a whitespace separated list
    def SetServers(servers_s)
      @servers = Builtins.filter(Builtins.splitstring(servers_s, " \t")) do |s|
        s != ""
      end

      nil
    end

    # Read Netconfig configuration
    def getNetconfigValues
      Builtins.y2milestone("getNetconfigValues called")

      # reset the values
      @multidomain_servers = {}
      @multidomain_broadcast = {}
      @slp_domain = {}
      @servers = []

      @policy = Convert.to_string(
        SCR.Read(path(".sysconfig.network.config.NETCONFIG_NIS_POLICY"))
      )
      Builtins.y2milestone("policy : %1", @policy)
      @policy = "" if @policy.nil?

      staticVals = {}
      keylist = SCR.Dir(path(".sysconfig.network.config"))

      Builtins.y2milestone("KEYLIST: %1", keylist)

      keylist = [] if keylist.nil?

      Builtins.foreach(keylist) do |key|
        if !Builtins.issubstring(key, "NETCONFIG_NIS_STATIC_DOMAIN") &&
            !Builtins.issubstring(key, "NETCONFIG_NIS_STATIC_SERVERS")
          next
        end

        value = Convert.to_string(
          SCR.Read(Builtins.add(path(".sysconfig.network.config"), key))
        )
        Builtins.y2milestone("Found %1 = %2", key, value)
        num = ""
        if key == "NETCONFIG_NIS_STATIC_DOMAIN"
          Ops.set(
            staticVals,
            "0",
            Builtins.add(Ops.get(staticVals, "0", {}), "DOMAIN", value)
          )
        elsif key == "NETCONFIG_NIS_STATIC_SERVERS"
          Ops.set(
            staticVals,
            "0",
            Builtins.add(Ops.get(staticVals, "0", {}), "SERVERS", value)
          )
        else
          @static_keylist = Builtins.add(@static_keylist, key)
          num = Builtins.regexpsub(
            key,
            "^NETCONFIG_NIS_STATIC_(DOMAIN|SERVERS)_(.*)",
            "\\2"
          )
          Builtins.y2milestone("try to get the number: %1", num)
          if Builtins.issubstring(key, "NETCONFIG_NIS_STATIC_DOMAIN")
            Ops.set(
              staticVals,
              num,
              Builtins.add(Ops.get(staticVals, num, {}), "DOMAIN", value)
            )
          elsif Builtins.issubstring(key, "NETCONFIG_NIS_STATIC_SERVERS")
            Ops.set(
              staticVals,
              num,
              Builtins.add(Ops.get(staticVals, num, {}), "SERVERS", value)
            )
          end
        end
      end

      Builtins.y2milestone("STATIC VALS: %1", staticVals)

      Builtins.foreach(staticVals) do |key, value|
        if Ops.get(value, "DOMAIN") == ""
          if Ops.get(value, "SERVERS", "") != ""
            sr = Ops.add(
              Ops.add(GetServers(), " "),
              Ops.get(value, "SERVERS", "")
            )
            SetServers(sr)
          end
        elsif Ops.get(value, "DOMAIN") == "broadcast"
          @global_broadcast = true
        elsif Ops.get(value, "DOMAIN", "") != ""
          if Ops.get(value, "SERVERS") == "broadcast"
            @default_broadcast = true if key == "0"
            Ops.set(@multidomain_broadcast, Ops.get(value, "DOMAIN", ""), true)
          elsif Ops.get(value, "SERVERS") == "slp"
            Ops.set(@slp_domain, Ops.get(value, "DOMAIN", ""), true)
          elsif Ops.get(value, "SERVERS", "") != ""
            Ops.set(
              @multidomain_servers,
              Ops.get(value, "DOMAIN", ""),
              Builtins.splitstring(Ops.get(value, "SERVERS", ""), " ")
            )
          end
        end
      end

      Builtins.foreach(@multidomain_servers) do |domain, _value|
        Ops.set(@multidomain_broadcast, domain, false) if !Builtins.haskey(@multidomain_broadcast, domain)
      end

      Builtins.foreach(@multidomain_broadcast) do |domain, _value|
        Ops.set(@multidomain_servers, domain, []) if !Builtins.haskey(@multidomain_servers, domain)
      end

      Builtins.foreach(
        Convert.convert(@slp_domain, from: "map", to: "map <string, any>")
      ) do |domain, _value|
        Ops.set(@multidomain_servers, domain, []) if !Builtins.haskey(@multidomain_servers, domain)
      end

      Builtins.y2milestone("Servers: %1", @servers)
      Builtins.y2milestone("multidomain_servers: %1", @multidomain_servers)
      Builtins.y2milestone("multidomain_broadcast: %1", @multidomain_broadcast)
      Builtins.y2milestone("slp_domain: %1", @slp_domain)
      Builtins.y2milestone("default_broadcast: %1", @default_broadcast)

      nil
    end

    # Write the netconfig configuration
    def setNetconfigValues
      SCR.Write(path(".sysconfig.network.config.NETCONFIG_NIS_POLICY"), @policy)

      Builtins.foreach(@multidomain_servers) do |domain, _value|
        Ops.set(@multidomain_broadcast, domain, false) if !Builtins.haskey(@multidomain_broadcast, domain)
      end

      Builtins.foreach(@multidomain_broadcast) do |domain, _value|
        Ops.set(@multidomain_servers, domain, []) if !Builtins.haskey(@multidomain_servers, domain)
      end

      Builtins.foreach(
        Convert.convert(@slp_domain, from: "map", to: "map <string, any>")
      ) do |domain, _value|
        Ops.set(@multidomain_servers, domain, []) if !Builtins.haskey(@multidomain_servers, domain)
      end

      Builtins.foreach(@static_keylist) do |key|
        Builtins.y2milestone("Remove : %1", key)
        SCR.Write(Builtins.add(path(".sysconfig.network.config"), key), nil)
      end

      # remove the content of this
      SCR.Write(
        path(".sysconfig.network.config.NETCONFIG_NIS_STATIC_DOMAIN"),
        ""
      )
      SCR.Write(
        path(".sysconfig.network.config.NETCONFIG_NIS_STATIC_SERVERS"),
        ""
      )

      Builtins.y2milestone("Servers: %1", @servers)
      Builtins.y2milestone("multidomain_servers: %1", @multidomain_servers)
      Builtins.y2milestone("multidomain_broadcast: %1", @multidomain_broadcast)
      Builtins.y2milestone("slp_domain: %1", @slp_domain)
      Builtins.y2milestone("default_broadcast: %1", @default_broadcast)

      cnt = 0
      if Ops.greater_than(Builtins.size(@servers), 0)
        SCR.Write(
          path(".sysconfig.network.config.NETCONFIG_NIS_STATIC_DOMAIN"),
          ""
        )
        SCR.Write(
          path(".sysconfig.network.config.NETCONFIG_NIS_STATIC_SERVERS"),
          Builtins.mergestring(@servers, " ")
        )
        cnt = Ops.add(cnt, 1)
      end

      Builtins.foreach(
        Convert.convert(
          @multidomain_servers,
          from: "map <string, list>",
          to:   "map <string, list <string>>"
        )
      ) do |dom, srvs|
        next if dom == ""

        if Ops.greater_than(Builtins.size(srvs), 0)
          if cnt == 0
            SCR.Write(
              path(".sysconfig.network.config.NETCONFIG_NIS_STATIC_DOMAIN"),
              dom
            )
            SCR.Write(
              path(".sysconfig.network.config.NETCONFIG_NIS_STATIC_SERVERS"),
              Builtins.mergestring(srvs, " ")
            )
          else
            SCR.Write(
              Builtins.add(
                path(".sysconfig.network.config"),
                Ops.add("NETCONFIG_NIS_STATIC_DOMAIN_", cnt)
              ),
              dom
            )
            SCR.Write(
              Builtins.add(
                path(".sysconfig.network.config"),
                Ops.add("NETCONFIG_NIS_STATIC_SERVERS_", cnt)
              ),
              Builtins.mergestring(srvs, " ")
            )
          end
          cnt = Ops.add(cnt, 1)
        end
        if Ops.get(@multidomain_broadcast, dom, false) == true
          if cnt == 0
            SCR.Write(
              path(".sysconfig.network.config.NETCONFIG_NIS_STATIC_DOMAIN"),
              dom
            )
            SCR.Write(
              path(".sysconfig.network.config.NETCONFIG_NIS_STATIC_SERVERS"),
              "broadcast"
            )
          else
            SCR.Write(
              Builtins.add(
                path(".sysconfig.network.config"),
                Ops.add("NETCONFIG_NIS_STATIC_DOMAIN_", cnt)
              ),
              dom
            )
            SCR.Write(
              Builtins.add(
                path(".sysconfig.network.config"),
                Ops.add("NETCONFIG_NIS_STATIC_SERVERS_", cnt)
              ),
              "broadcast"
            )
          end
          cnt = Ops.add(cnt, 1)
        end
        if Ops.get_boolean(@slp_domain, dom, false) == true
          if cnt == 0
            SCR.Write(
              path(".sysconfig.network.config.NETCONFIG_NIS_STATIC_DOMAIN"),
              dom
            )
            SCR.Write(
              path(".sysconfig.network.config.NETCONFIG_NIS_STATIC_SERVERS"),
              "slp"
            )
          else
            SCR.Write(
              Builtins.add(
                path(".sysconfig.network.config"),
                Ops.add("NETCONFIG_NIS_STATIC_DOMAIN_", cnt)
              ),
              dom
            )
            SCR.Write(
              Builtins.add(
                path(".sysconfig.network.config"),
                Ops.add("NETCONFIG_NIS_STATIC_SERVERS_", cnt)
              ),
              "slp"
            )
          end
          cnt = Ops.add(cnt, 1)
        end
      end

      if @default_broadcast == true
        if cnt == 0
          SCR.Write(
            path(".sysconfig.network.config.NETCONFIG_NIS_STATIC_DOMAIN"),
            @domain
          )
          SCR.Write(
            path(".sysconfig.network.config.NETCONFIG_NIS_STATIC_SERVERS"),
            "broadcast"
          )
        else
          SCR.Write(
            Builtins.add(
              path(".sysconfig.network.config"),
              Ops.add("NETCONFIG_NIS_STATIC_DOMAIN_", cnt)
            ),
            @domain
          )
          SCR.Write(
            Builtins.add(
              path(".sysconfig.network.config"),
              Ops.add("NETCONFIG_NIS_STATIC_SERVERS_", cnt)
            ),
            "broadcast"
          )
        end
        cnt = Ops.add(cnt, 1)
      elsif @global_broadcast == true
        if cnt == 0
          SCR.Write(
            path(".sysconfig.network.config.NETCONFIG_NIS_STATIC_DOMAIN"),
            "broadcast"
          )
          SCR.Write(
            path(".sysconfig.network.config.NETCONFIG_NIS_STATIC_SERVERS"),
            ""
          )
        else
          SCR.Write(
            Builtins.add(
              path(".sysconfig.network.config"),
              Ops.add("NETCONFIG_NIS_STATIC_DOMAIN_", cnt)
            ),
            "broadcast"
          )
          SCR.Write(
            Builtins.add(
              path(".sysconfig.network.config"),
              Ops.add("NETCONFIG_NIS_STATIC_SERVERS_", cnt)
            ),
            ""
          )
        end
        cnt = Ops.add(cnt, 1)
      end

      if !SCR.Write(path(".sysconfig.network.config"), nil)
        Report.Error(Message.ErrorWritingFile("/etc/sysconfig/network/config"))
        return false
      end
      true
    end

    # If the domain has changed from a nonempty one, it may only be
    # changed at boot time. Use this to warn the user.
    # @return whether changed by SetDomain
    def DomainChanged
      @domain_changed
    end

    # @return Get the NIS domain.
    def GetDomain
      @domain
    end

    # Set the NIS domain.
    # @param [String] new_domain a new domain
    def SetDomain(new_domain)
      @domain = new_domain
      @domain_changed = true if @domain != @old_domain && @old_domain != ""

      nil
    end

    # ----------------------------------------------------------------
    # used also for nis-server

    # Check syntax of a NIS domain name
    # @param [String] domain  a domain name
    # @return    true if correct
    def check_nisdomainname(domain)
      # TODO
      # disallow whitespace and special characters...
      domain != "" && domain != "(none)" &&
        Ops.less_or_equal(Builtins.size(domain), 64)
    end

    # @return describe a valid NIS domain name
    def valid_nisdomainname
      # Translators: do not translate (none)!
      _(
        "A NIS domain name must not be empty,\n" \
          "it must not be \"(none)\",\n" \
          "and it must be at most 64 characters long.\n"
      )
    end

    # Used in the UI when NIS is turned on.
    def UsersByLdap
      @users_by_ldap
    end

    # Describe a valid address - ip4 or name, names only if
    # nsswitch.conf does not have hosts: nis
    # @return a description
    def valid_address_nis
      Builtins.y2debug("hosts_by_nis %1", @hosts_by_nis)
      if @hosts_by_nis
        # message popup
        return Ops.add(
          _(
            "Only an IP address can be used\n" \
              "because host names are resolved using NIS.\n" \
              "\n"
          ),
          IP.Valid4
        )
      else
        return Address.Valid4
      end
    end

    # Check syntax of a network address (ip4 or name), names only if
    # nsswitch.conf does not have hosts: nis
    # @param [String] a an address
    # @return true if correct
    def check_address_nis(a)
      Builtins.y2debug("hosts_by_nis %1", @hosts_by_nis)
      if @hosts_by_nis
        return IP.Check4(a)
      else
        return Address.Check(a)
      end
    end

    # A convenient shortcut for setting touched.
    # @param [Boolean] really  if true, set Nis::touched
    # @example Nis::Touch (Nis::var != ui_var);
    def Touch(really)
      @touched ||= really

      nil
    end

    # Detect which packages have to be installed
    # and return a descriptive string for a plain text pop-up.
    # @return "" or "Foo will be installed.\nBar will be installed.\n"
    def ProbePackages
      message = ""
      @install_packages = []

      if @_autofs_allowed && @_start_autofs
        if !Package.Installed("autofs")
          @install_packages = Builtins.add(@install_packages, "autofs")
          # Translators: popup message part, ends with a newline
          message = Ops.add(
            message,
            _("The automounter package will be installed.\n")
          )
        end
        @install_packages = Builtins.add(@install_packages, "nfs-client") if !Package.Installed("nfs-client")
      end

      message
    end

    # ----------------------------------------------------------------

    # Set module data
    # @return [void]
    def Set(settings)
      settings = deep_copy(settings)
      @start = Ops.get_boolean(settings, "start_nis", false)

      @servers = Ops.get_list(settings, "nis_servers", [])
      @default_broadcast = Ops.get_boolean(settings, "nis_broadcast", false)
      @domain = Ops.get_string(settings, "nis_domain", "")
      @old_domain = @domain

      # we don't know what the state will be before Write, so restart it
      @dhcp_restart = true

      other_domains = Ops.get_list(settings, "nis_other_domains", [])
      Builtins.foreach(other_domains) do |other_domain|
        domain = Ops.get_string(other_domain, "nis_domain", "")
        servers = Ops.get_list(other_domain, "nis_servers", [])
        b = Ops.get_boolean(other_domain, "nis_broadcast", false)
        Ops.set(@multidomain_servers, domain, servers)
        Ops.set(@multidomain_broadcast, domain, b)
      end

      @local_only = Ops.get_boolean(settings, "nis_local_only", false)
      @broken_server = Ops.get_boolean(settings, "nis_broken_server", false)
      @options = Ops.get_string(settings, "nis_options", "")

      # autofs is not touched in Write if the map does not want it
      @_autofs_allowed = Builtins.haskey(settings, "start_autofs")
      @_start_autofs = Ops.get_boolean(settings, "start_autofs", false)
      if @_start_autofs
        @required_packages = Convert.convert(
          Builtins.union(@required_packages, ["autofs", "nfs-client"]),
          from: "list",
          to:   "list <string>"
        )
      end

      @policy = Ops.get_string(settings, "netconfig_policy", @policy)
      @slp_domain = Ops.get_map(settings, "slp_domain", @slp_domain)

      @touched = true

      nil
    end

    # TODO: update the map keys
    # better still: link to a current interface description
    # Get all the NIS configuration from a map.
    # When called by nis_auto (preparing autoinstallation data)
    # the map may be empty.
    # @param [Hash] settings  $["start": "domain": "servers":[...] ]
    # @return  success
    def Import(settings)
      settings = deep_copy(settings)
      if Builtins.size(settings) == 0
        # Provide defaults for autoinstallation editing:
        # Leave empty.
        @old_domain = @domain
        # enable _autofs_allowed
        # Injecting it into the defaults for the GUI
        # but leaving the check in Set makes it possible
        # to delete the element manually from the xml profile
        # and leave autofs untouched
        Ops.set(settings, "start_autofs", false)
        Set(settings)
        return true
      end

      missing = false
      # "nis_domain" can be omitted if nis_by_dhcp is true
      Builtins.foreach(["start_nis"]) do |k|
        if !Builtins.haskey(settings, k)
          Builtins.y2error("Missing at Import: '%1'.", k)
          missing = true
        end
      end
      return false if missing

      Set(settings)
      true
    end

    # TODO: update the map keys
    # better still: link to a current interface description
    # Dump the NIS settings to a map, for autoinstallation use.
    # @return $["start":, "servers":[...], "domain":]
    def Export
      return {} unless Yast::Mode.config || Yast::Package.Installed(NIS_CLIENT_PACKAGE)

      other_domains = Builtins.maplist(@multidomain_servers) do |d, s|
        {
          "nis_domain"    => d,
          "nis_servers"   => s,
          "nis_broadcast" => Ops.get(@multidomain_broadcast, d, false)
        }
      end

      Builtins.y2error("Attempt to export Nis::global_broadcast") if @global_broadcast

      {
        "start_nis"         => @start,
        "nis_servers"       => @servers,
        "nis_domain"        => @domain,
        "nis_broadcast"     => @default_broadcast,
        "nis_other_domains" => other_domains,
        "nis_local_only"    => @local_only,
        "nis_broken_server" => @broken_server,
        "nis_options"       => @options,
        "start_autofs"      => @_start_autofs,
        "slp_domain"        => @slp_domain,
        "netconfig_policy"  => @policy
      }
    end

    # copied from Mail.ycp
    # replace with a custom list
    # Summarizes a list of data
    # @param [String] title passed to Summary::AddHeader
    # @param [Object] value a list (of scalars, lists or maps)
    # @return Summary-formatted description
    def ListItem(title, value)
      value = deep_copy(value)
      summary = ""
      summary = Summary.AddHeader(summary, title)
      # enhancement BEGIN
      value = Builtins.maplist(Convert.to_map(value)) { |k, _v| k } if Ops.is_map?(
        value
      )
      # enhancement END
      if Ops.is_list?(value) &&
          Ops.greater_than(Builtins.size(Convert.to_list(value)), 0)
        summary = Summary.OpenList(summary)
        Builtins.foreach(Convert.to_list(value)) do |d|
          entry = if Ops.is_map?(d) || Ops.is_list?(d)
            Builtins.sformat(
              "%1 Entries configured",
              Ops.is_map?(d) ? Builtins.size(Convert.to_map(value)) : Builtins.size(Convert.to_list(value))
            )
          else
            Convert.to_string(d)
          end
          summary = Summary.AddListItem(summary, entry)
        end
        summary = Summary.CloseList(summary)
      else
        summary = Summary.AddLine(summary, Summary.NotConfigured)
      end
      summary
    end

    # @return Html formatted configuration summary
    def Summary
      # TODO: multidomain_servers, multidomain_broadcast
      # OK, a dumb mapping is possible, but wouldn't it be
      # too complicated to write by hand?
      summary = ""
      nc = Summary.NotConfigured

      # summary header
      summary = Summary.AddHeader(summary, _("NIS Client enabled"))
      # summary item: an option is turned on
      summary = Summary.AddLine(summary, @start ? _("Yes") : nc)
      # summary header
      summary = Summary.AddHeader(summary, _("NIS Domain"))
      summary = Summary.AddLine(summary, (@domain != "") ? @domain : nc)
      # summary header
      summary = Summary.AddHeader(summary, _("NIS Servers"))
      summary = Summary.AddLine(
        summary,
        (@servers != []) ? Builtins.mergestring(@servers, "<br>") : nc
      )
      # summary header
      summary = Summary.AddHeader(summary, _("Broadcast"))
      # summary item: an option is turned on
      summary = Summary.AddLine(summary, @default_broadcast ? _("Yes") : nc)
      # TODO: a full list
      summary = Ops.add(
        summary,
        ListItem(_("Other domains"), @multidomain_servers)
      )
      # summary header
      summary = Summary.AddHeader(summary, _("Answer to local host only"))
      # summary item: an option is turned on
      summary = Summary.AddLine(summary, @local_only ? _("Yes") : nc)
      # summary header
      summary = Summary.AddHeader(summary, _("Broken server"))
      # summary item: an option is turned on
      summary = Summary.AddLine(summary, @broken_server ? _("Yes") : nc)
      # summary header
      summary = Summary.AddHeader(summary, _("ypbind options"))
      summary = Summary.AddLine(summary, (@options != "") ? @options : nc)
      # summary header
      summary = Summary.AddHeader(summary, _("Automounter enabled"))
      # summary item: an option is turned on
      summary = Summary.AddLine(summary, @_start_autofs ? _("Yes") : nc)

      summary
    end

    # Makes an item for the short summary. I guess the users module
    # wants to avoid paragraph breaks.
    # @param [String] title
    # @param [String] value
    # @return [b]title[/b]: value[br]
    def BrItem(title, value)
      Builtins.sformat("<b>%1</b>: %2<br>", title, value)
    end

    # Create a short textual summary with configuration abstract
    # It is called by "authentication/user sources" dialog in yast2-users
    # @return summary of the current configuration
    def ShortSummary
      nc = Summary.NotConfigured
      summary = Ops.add(
        Ops.add(
          # summary item
          BrItem(_("Servers"), (@servers != []) ? GetServers() : nc),
          # summary item
          BrItem(_("Domain"), (@domain != "") ? @domain : nc)
        ),
        # summary item (yes/no follows)
        BrItem(_("Client Enabled"), @start ? _("Yes") : _("No"))
      )

      summary
    end

    # Reads NIS settings from the SCR
    # @return success
    def Read
      @start = Service.Enabled("ypbind")

      getNetconfigValues

      @servers = [] if @servers.nil?
      @default_broadcast = false if @default_broadcast.nil?
      @multidomain_servers = {} if @multidomain_servers.nil?
      @multidomain_broadcast = {} if @multidomain_broadcast.nil?
      @slp_domain = {} if @slp_domain.nil?

      out = SCR.Execute(path(".target.bash_output"), "/usr/bin/ypdomainname")
      # 0 OK, 1 mean no domain name set, so no nis, do not report it
      Report.Error(_("Getting domain name via ypdomainname failed with '%s'") % out["stderr"]) if out["exit"] > 1
      @domain = out["stdout"].chomp
      @old_domain = @domain

      @dhcpcd_running = SCR.Execute(
        path(".target.bash"),
        "/usr/bin/ls /var/run/dhcpcd-*.pid"
      ) == 0

      @local_only = SCR.Read(path(".sysconfig.ypbind.YPBIND_LOCAL_ONLY")) == "yes"
      @global_broadcast = SCR.Read(path(".sysconfig.ypbind.YPBIND_BROADCAST")) == "yes"
      @broken_server = SCR.Read(path(".sysconfig.ypbind.YPBIND_BROKEN_SERVER")) == "yes"
      @options = SCR.Read(path(".sysconfig.ypbind.YPBIND_OPTIONS")).to_s

      # install on demand
      @_start_autofs = @_autofs_allowed && Service.Enabled("autofs")

      @hosts_by_nis = Builtins.contains(Nsswitch.ReadDb("hosts"), "nis")

      nss_passwd = Nsswitch.ReadDb("passwd")
      @users_by_ldap = Builtins.contains(nss_passwd, "ldap") ||
        Builtins.contains(nss_passwd, "compat") &&
          Builtins.contains(Nsswitch.ReadDb("passwd_compat"), "ldap")

      Autologin.Read

      Y2Firewall::Firewalld.instance.read

      true
    end

    # Make up data for screnshots.
    # To be used instead of {#Read} .
    def Fake
      Builtins.y2milestone("Faking data for screenshots")
      @start = true
      @servers = ["10.42.0.1"]
      @default_broadcast = false
      @multidomain_servers = {
        "printer.example.com" => [],
        "test.example.com"    => ["10.42.1.1", "10.42.1.2"]
      }
      @multidomain_broadcast = {
        "printer.example.com" => true,
        "test.example.com"    => false
      }
      @domain = "example.com"
      @old_domain = @domain
      @local_only = false
      @global_broadcast = false
      @broken_server = false
      @options = ""
      @_autofs_allowed = true
      @_start_autofs = true
      @hosts_by_nis = false

      nil
    end

    # @param [String] file a pathname
    # @return is there a nis inclusion?
    def HasPlus(file)
      # does the file have a plus?
      Builtins.y2milestone("file %1 has pluses", file)
      0 ==
        SCR.Execute(
          path(".target.bash"),
          "/usr/bin/grep -q '^[+-]' #{file.shellescape}"
        )
    end

    # If a file does not contain a NIS entry, add it.
    # @param [String] file  pathname
    # @param [String] what  a "+" line without a '\n'
    # @return success?
    def WritePlusesTo(file, what)
      ok = true
      if !HasPlus(file)
        # backup the file:
        SCR.Execute(
          path(".target.bash"),
          Builtins.sformat("/usr/bin/cp %1 %1.YaST2save", file.shellescape)
        )
        if SCR.Execute(
          path(".target.bash"),
          Builtins.sformat("/usr/bin/echo %1 >> %2", what.shellescape, file.shellescape)
        ) != 0
          ok = false
        end
      # TODO: only for passwd?
      # replace the 'nologin' occurence (#40571)
      elsif SCR.Execute(
        path(".target.bash"),
        Builtins.sformat("/usr/bin/grep -q ^%1/sbin/nologin %2", what.shellescape, file.shellescape)
      ) == 0
        ok = SCR.Execute(
          path(".target.bash"),
          Builtins.sformat(
            "/usr/bin/sed -i.YaST2save -e s@%1/sbin/nologin@%1@ %2",
            what.shellescape,
            file.shellescape
          )
        ) == 0
      end
      Report.Error(Message.ErrorWritingFile(file)) if !ok
      ok
    end

    # Do we need compat? Is there a plus in any of the user databases?
    #
    # @return [Boolean]
    def has_plus?
      files = ["/etc/passwd", "/etc/shadow", "/etc/group"]
      # find a file having a plus
      nil != Builtins.find(files) { |file| HasPlus(file) }
    end

    # Add "+" lines to system files so that NIS entries get merged in.
    # @return success?
    def WritePluses
      files = ["passwd", "shadow", "group"]
      # don't forget a newline
      what_to_write = {
        "passwd" => "+::::::",
        "group"  => "+:::",
        "shadow" => "+"
      }
      Builtins.foreach(files) do |f|
        Builtins.y2milestone("Writing pluses to %1", f)
        if !WritePlusesTo(
          Builtins.sformat("/etc/%1", f),
          Ops.get_string(what_to_write, f, "")
        )
          next false
        end
      end
      true
    end

    # Configures the name service switch for the user databases according to chosen settings
    #
    # @return [Boolean] true on success; false otherwise
    def WriteNssConf
      dbs = ["passwd", "group", "shadow"]

      nis_dbs = ["services", "netgroup", "aliases"]

      # Why bother with both compat and nis?
      # If there's no plus, we don't have to write passwd etc.
      # And it's supposed to be faster.
      # But then programs have to reread nsswitch :( #23203
      # so we stick with compat.
      if @start
        # we want to switch to "compat"
        dbs.each do |db|
          # what if a db is not mentioned?
          # We get [] meaning compat, so it's ok to make it explicit
          db_l = Nsswitch.ReadDb(db)

          if !db_l.include?("compat")
            # remove "files" and "nis", if there;
            db_l -= ["files", "nis"]

            # put "compat" and the rest;
            db_l.prepend("compat")

            Nsswitch.WriteDb(db, db_l)
          end

          # *_compat may be set to nisplus, nuke it (#16168)
          db_c = db + "_compat"

          Nsswitch.WriteDb(db_c, [])
        end

        Builtins.y2milestone("Writing pluses")

        WritePluses()

        nis_dbs.each do |db|
          db_l = Nsswitch.ReadDb(db)

          next if db_l.include?("nis")

          if db == "netgroup"
            db_l = ["nis"]
          else
            db_l << "nis"
          end

          Nsswitch.WriteDb(db, db_l)
        end
      else
        Builtins.y2milestone("not writing pluses")

        if !has_plus?
          dbs.each do |db|
            db_l = Nsswitch.ReadDb(db)

            # remove "nis" if there;
            db_l -= ["nis"]

            # if nothing left, put "files";
            # NOT. just remove it, meaning compat. #35299
            Nsswitch.WriteDb(db, db_l)
          end
        end

        nis_dbs.each do |db|
          db_l = Nsswitch.ReadDb(db)

          db_l -= ["nis"]
          db_l = ["files", "usrfiles"] if db_l.empty?

          Nsswitch.WriteDb(db, db_l)
        end
      end

      Nsswitch.Write
    end

    # Only write new configuration w/o starting any scripts
    # @return true on success
    def WriteOnly
      if @start
        @rpc_mapper = if Package.Installed("rpcbind")
          "rpcbind"
        else
          "portmap"
        end

        Service.Enable(@rpc_mapper)
        Service.Enable("ypbind")

        if !SCR.Write(path(".etc.defaultdomain"), @domain)
          Report.Error(Message.ErrorWritingFile("/etc/defaultdomain"))
          return false
        end

        # so that dhcpcd cannot restore it
        SCR.Execute(path(".target.remove"), "/etc/yp.conf.sv")

        setNetconfigValues

        SCR.Execute(path(".target.bash"), "/sbin/netconfig update")

        SCR.Write(
          path(".sysconfig.ypbind.YPBIND_LOCAL_ONLY"),
          @local_only ? "yes" : "no"
        )
        SCR.Write(
          path(".sysconfig.ypbind.YPBIND_BROADCAST"),
          @global_broadcast ? "yes" : "no"
        )
        SCR.Write(
          path(".sysconfig.ypbind.YPBIND_BROKEN_SERVER"),
          @broken_server ? "yes" : "no"
        )
        SCR.Write(path(".sysconfig.ypbind.YPBIND_OPTIONS"), @options)
        if !SCR.Write(path(".sysconfig.ypbind"), nil)
          Report.Error(Message.ErrorWritingFile("/etc/sysconfig/ypbind"))
          return false
        end

        SCR.Write(
          path(".sysconfig.network.config.NETCONFIG_NIS_SETDOMAINNAME"),
          (@policy == "") ? "no" : "yes"
        )

        if !SCR.Write(path(".sysconfig.network.dhcp"), nil)
          Report.Error(Message.ErrorWritingFile("/etc/sysconfig/network/dhcp"))
          return false
        end
        Autologin.Write(false)
      else
        Service.Disable("ypbind")
      end

      # TODO: do as much as possible if one thing fails
      # especially WRT nis/autofs independence
      WriteNssConf()

      if @_autofs_allowed
        return false if !Nsswitch.WriteAutofs(@start && @_start_autofs, "nis")

        if @_start_autofs
          Service.Enable("autofs")
        else
          Service.Disable("autofs")
        end
      end

      Y2Firewall::Firewalld.instance.write_only

      true
    end

    # Saves NIS configuration.
    # @return true on success
    def Write
      return false if !WriteOnly()

      # dialog label
      Progress.New(
        _("Writing NIS Configuration..."),
        " ",
        2,
        [
          # progress stage label
          _("Stop services"),
          # progress stage label
          _("Start services")
        ],
        [
          # progress step label
          _("Stopping services..."),
          # progress step label
          _("Starting services..."),
          # final progress step label
          _("Finished")
        ],
        ""
      )

      # help text
      Wizard.RestoreHelp(_("Writing NIS client settings"))

      Progress.NextStage

      if @dhcp_restart
        # Restart the dhcp client, if it is running, to parse the changed
        # options
        Service.RunInitScript("network", "restart-all-dhcp-clients")
      end

      Service.Stop("ypbind")

      Progress.NextStage

      if @start
        if Service.Status(@rpc_mapper) != 0
          if Service.Start(@rpc_mapper) == false
            Message.CannotStartService(@rpc_mapper)
            return false
          end
        end
        Builtins.sleep(1000) # workaround for bug #10428, ypbind restart

        if !Service.Start("ypbind")
          # error popup message
          Report.Error(_("Error while running ypclient."))
          return false
        end

        # only test for a server if domain not changed
        if !@domain_changed
          if SCR.Execute(path(".target.bash"), "/usr/bin/ypwhich >/dev/null") != 0
            # error popup message
            Report.Error(_("NIS server not found."))
            return false
          end
        end
      end

      # remove nscd cache
      if Package.Installed("nscd") && @modified
        SCR.Execute(path(".target.bash"), "/usr/sbin/nscd -i passwd")
        SCR.Execute(path(".target.bash"), "/usr/sbin/nscd -i group")
      end

      if @_autofs_allowed && @touched
        Service.Stop("autofs")

        Service.Start("autofs") if @_start_autofs
      end

      # adapt PAM if needed (bnc#848963)
      if @touched && Pam.Enabled("unix")
        if @start
          Pam.Add("unix-nis")
        else
          Pam.Remove("unix-nis")
        end
      end

      Y2Firewall::Firewalld.instance.reload
      # final stage
      Progress.NextStage

      true
    end

    # Return needed packages and packages to be removed
    # during autoinstallation.
    # @return [Hash] of lists.
    #
    #

    def AutoPackages
      install_pkgs = deep_copy(@required_packages)
      remove_pkgs = []
      { "install" => install_pkgs, "remove" => remove_pkgs }
    end

    publish variable: :modified, type: "boolean"
    publish function: :SetModified, type: "void ()"
    publish function: :GetModified, type: "boolean ()"
    publish variable: :required_packages, type: "list <string>"
    publish variable: :start, type: "boolean"
    publish variable: :servers, type: "list <string>"
    publish function: :GetServers, type: "string ()"
    publish function: :SetServers, type: "void (string)"
    publish variable: :default_broadcast, type: "boolean"
    publish variable: :multidomain_servers, type: "map <string, list>"
    publish variable: :multidomain_broadcast, type: "map <string, boolean>"
    publish variable: :global_broadcast, type: "boolean"
    publish variable: :slp_domain, type: "map"
    publish variable: :policy, type: "string"
    publish function: :getNetconfigValues, type: "void ()"
    publish function: :setNetconfigValues, type: "boolean ()"
    publish function: :DomainChanged, type: "boolean ()"
    publish function: :GetDomain, type: "string ()"
    publish function: :SetDomain, type: "void (string)"
    publish variable: :dhcpcd_running, type: "boolean"
    publish variable: :dhcp_restart, type: "boolean"
    publish variable: :local_only, type: "boolean"
    publish variable: :broken_server, type: "boolean"
    publish variable: :options, type: "string"
    publish variable: :_autofs_allowed, type: "boolean"
    publish variable: :_start_autofs, type: "boolean"
    publish variable: :YpbindErrors, type: "string"
    publish function: :check_nisdomainname, type: "boolean (string)"
    publish function: :valid_nisdomainname, type: "string ()"
    publish function: :UsersByLdap, type: "boolean ()"
    publish function: :valid_address_nis, type: "string ()"
    publish function: :check_address_nis, type: "boolean (string)"
    publish variable: :touched, type: "boolean"
    publish function: :Touch, type: "void (boolean)"
    publish variable: :install_packages, type: "list <string>"
    publish function: :ProbePackages, type: "string ()"
    publish function: :Set, type: "void (map)"
    publish function: :Import, type: "boolean (map)"
    publish function: :Export, type: "map ()"
    publish function: :Summary, type: "string ()"
    publish function: :BrItem, type: "string (string, string)"
    publish function: :ShortSummary, type: "string ()"
    publish function: :Read, type: "boolean ()"
    publish function: :Fake, type: "void ()"
    publish function: :WriteNssConf, type: "boolean ()"
    publish function: :WriteOnly, type: "boolean ()"
    publish function: :Write, type: "boolean ()"
    publish function: :AutoPackages, type: "map ()"
  end

  Nis = NisClass.new
  Nis.main
end
