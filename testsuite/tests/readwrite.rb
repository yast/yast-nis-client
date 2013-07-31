# encoding: utf-8

# Module:
#   NIS client configuration
#
# Summary:
#   Testsuite
#
# Authors:
#   Martin Vidner <mvidner@suse.cz>
#
# $Id$
module Yast
  class ReadwriteClient < Client
    def main
      # testedfiles: Nis.ycp Autologin.ycp Service.ycp Report.ycp Testsuite.ycp Nsswitch.ycp

      Yast.include self, "testsuite.rb"

      @READ_INIT = { "target" => { "size" => 0 } }
      @EXEC_INIT = { "target" => { "bash_output" => {} } }

      TESTSUITE_INIT([@READ_INIT, {}, @EXEC_INIT], nil)

      Yast.import "Pkg" # override
      Yast.import "Nis"


      @READ = {
        # Runlevel:
        "init"      => {
          "scripts" => {
            "exists"   => true,
            "runlevel" => {
              "rpcbind" => { "start" => ["3", "5"], "stop" => ["3", "5"] },
              "ypbind"  => { "start" => ["3", "5"], "stop" => ["3", "5"] },
              "autofs"  => { "start" => ["3", "5"], "stop" => ["3", "5"] }
            },
            # their contents is not important for ServiceAdjust
            "comment"  => {
              "rpcbind" => {},
              "ypbind"  => {},
              "autofs"  => {}
            }
          }
        },
        # Nis itself:
        "etc"       => {
          "yp_conf"       => {
            "servers"          => ["10.20.30.40", "10.20.30.80"],
            "slp"              => { "slpdomain" => true },
            "defaultbroadcast" => false,
            "domainservers"    => { "otherdomain" => ["1.2.3.4"] },
            "broadcast"        => { "otherdomain" => true }
          },
          #	    "defaultdomain": "mydomain",
          "nsswitch_conf" => {
            "passwd"    => "compat",
            "group"     => "compat",
            "hosts"     => "files dns6",
            "automount" => "files",
            "services"  => "files",
            "netgroup"  => "files",
            "aliases"   => "files"
          }
        },
        "sysconfig" => {
          "ypbind"         => {
            "YPBIND_LOCAL_ONLY"    => "no",
            "YPBIND_BROADCAST"     => "no",
            "YPBIND_BROKEN_SERVER" => "no",
            "YPBIND_OPTIONS"       => ""
          },
          "network"        => { "config" => { "NETCONFIG_NIS_POLICY" => "" } },
          "displaymanager" => {
            "DISPLAYMANAGER"                     => "kdm",
            "DISPLAYMANAGER_AUTOLOGIN"           => "no",
            "DISPLAYMANAGER_PASSWORD_LESS_LOGIN" => "no"
          }
        },
        "target"    => {
          "size" => 0,
          # FileUtils::Exists
          "stat" => { 1 => 2 }
        }
      }

      @WRITE = {}

      @EXECUTE = {
        "target" =>
          # /etc/yp.conf.sv
          {
            # ok if used both for `domainname` and `rcypbind start`
            "bash_output" => {
              "exit"   => 0,
              "stdout" => "mydomain\n",
              "stderr" => ""
            },
            "remove"      => true
          }
      }

      DUMP("no policy")
      TEST(lambda { Nis.Read }, [@READ, @WRITE, @EXECUTE], nil)
      TEST(lambda { Nis.Write }, [@READ, @WRITE, @EXECUTE], nil)

      DUMP("auto policy")
      Ops.set(
        @READ,
        ["sysconfig", "network", "config", "NETCONFIG_NIS_POLICY"],
        "auto"
      )
      TEST(lambda { Nis.Read }, [@READ, @WRITE, @EXECUTE], nil)
      TEST(lambda { Nis.Touch(true) }, [], nil)
      TEST(lambda { Nis.Write }, [@READ, @WRITE, @EXECUTE], nil)

      nil
    end
  end
end

Yast::ReadwriteClient.new.main
