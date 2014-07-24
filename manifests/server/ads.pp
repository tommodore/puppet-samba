# This module join samba server to Active Dirctory
#
# Copyright (c) 2013 Lebedev Vadim, abraham1901 at g mail dot c o m
# Licensed under the MIT License, http://opensource.org/licenses/MIT

class samba::server::ads($ensure = present,
  $ads_acct                   = 'admin',
  $ads_pass                   = 'SecretPass',
  $realm                      = 'domain.com',
  # $nsswitch                   = false,
  $acl_group_control          = 'yes',
  $map_acl_inherit            = 'yes',
  $inherit_acls               = 'yes',
  $store_dos_attributes       = 'yes',
  $ea_support                 = 'yes',
  $dos_filemode               = 'yes',
  $acl_check_permissions      = false,
  $map_system                 = 'no',
  $map_archive                = 'no',
  $map_readonly               = 'no',
  $password_server            = '127.0.0.1',
  $template_homedir           = '/home/%U',
  $template_shell             = '/bin/bash',
  $client_use_spnego          = yes,
  $client_ntlmv2_auth         = yes,
  $encrypt_passwords          = yes,
  $restrict_anonymous         = '2',
  $domain_master              = no,
  $local_master               = no,
  $preferred_master           = no,
  $os_level                   = '0',
  $default_domain             = "${::domain}",
  $kdc                        = 'kdc',
  $target_ou                  = 'Nix_Mashine') {

  $krb5_user_package = $osfamily ? {
    'RedHat' => 'krb5-workstation',
    default  => 'krb5-user',
  }

  if $osfamily == "RedHat" {
    if $operatingsystemrelease =~ /^6\./ {
      $winbind_package = 'samba-winbind'
    } else {
      $winbind_package = 'samba-common'
    }
  } else {
    $winbind_package = 'winbind'
  }

  package{
    $krb5_user_package: ensure => installed;
    $winbind_package:   ensure => installed;
    'expect':           ensure => installed;
  }

  include samba::server::config


  samba::server::option {
    'realm':                        value => $realm;
    'acl group control':            value => $acl_group_control;
    'map acl inherit':              value => $map_acl_inherit;
    'inherit acls':                 value => $inherit_acls;
    'store dos attributes':         value => $store_dos_attributes;
    'ea support':                   value => $ea_support;
    'dos filemode':                 value => $dos_filemode;
    'acl check permissions':        value => $acl_check_permissions;
    'map system':                   value => $map_system;
    'map archive':                  value => $map_archive;
    'map readonly':                 value => $map_readonly;
    'password server':              value => $password_server;
    'winbind cache time':           value => $winbind_cache_time;
    'template homedir':             value => $template_homedir;
    'template shell':               value => $template_shell;
    'client use spnego':            value => $client_use_spnego;
    'client ntlmv2 auth':           value => $client_ntlmv2_auth;
    'encrypt passwords':            value => $encrypt_passwords;
    'restrict anonymous':           value => $restrict_anonymous;
    'domain master':                value => $domain_master;
    'local master':                 value => $local_master;
    'preferred master':             value => $preferred_master;
    'os level':                     value => $os_level;
  }

  file {'krb5.conf':
    path    => '/etc/krb5.conf',
    owner   => 0,
    group   => 0,
    mode    => '0744',
    content => template("${module_name}/krb5.conf.erb"),
    require => Package[$krb5_user_package],
  }

  file {'verify_active_directory':
    # this script returns 0 if join is intact
    path    => '/sbin/verify_active_directory',
    owner   => root,
    group   => root,
    mode    => "0755",
    content => template("${module_name}/verify_active_directory.erb"),
    require => [ Package[$krb5_user_package, 'expect'],
      Augeas['samba-realm', 'samba-security']]
  }

  file {'configure_active_directory':
    # this script joins or leaves a domain
    path    => '/sbin/configure_active_directory',
    owner   => root,
    group   => root,
    mode    => "0755",
    content => template("${module_name}/configure_active_directory.erb"),
    require => [ Package[$krb5_user_package, 'expect'],
      Augeas['samba-realm', 'samba-security']]
  }

  exec {'join-active-directory':
    # join the domain configured in samba.conf
    command => '/sbin/configure_active_directory -j',
    unless  => '/sbin/verify_active_directory',
    require => File['configure_active_directory', 'verify_active_directory'],
  }
}
