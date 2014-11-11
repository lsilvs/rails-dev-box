$ar_databases = ['activerecord_unittest', 'activerecord_unittest2']
$as_ubuntu   = 'sudo -u ubuntu -H bash -l -c'
$home         = '/home/ubuntu'

# Pick a Ruby version modern enough, that works in the currently supported Rails
# versions, and for which RVM provides binaries.
$ruby_version = '2.1.2'

Exec {
  path => ['/usr/sbin', '/usr/bin', '/sbin', '/bin']
}

# --- Preinstall Stage ---------------------------------------------------------

stage { 'preinstall':
  before => Stage['main']
}

class apt_get_update {
  exec { 'apt-get -y update':
    unless => "test -e ${home}/.rvm"
  }
}
class { 'apt_get_update':
  stage => preinstall
}

# --- SQLite -------------------------------------------------------------------

package { ['sqlite3', 'libsqlite3-dev']:
  ensure => installed;
}

# --- MySQL --------------------------------------------------------------------

class install_mysql {
  class { 'mysql': }

  class { 'mysql::server':
    config_hash => { 'root_password' => '' }
  }

  database { $ar_databases:
    ensure  => present,
    charset => 'utf8',
    require => Class['mysql::server']
  }

  database_user { 'rails@localhost':
    ensure  => present,
    require => Class['mysql::server']
  }

  database_grant { ['rails@localhost/activerecord_unittest', 'rails@localhost/activerecord_unittest2', 'rails@localhost/inexistent_activerecord_unittest']:
    privileges => ['all'],
    require    => Database_user['rails@localhost']
  }

  package { 'libmysqlclient15-dev':
    ensure => installed
  }
}
class { 'install_mysql': }

# --- PostgreSQL ---------------------------------------------------------------

class install_postgres {
  class { 'postgresql': }

  class { 'postgresql::server': }

  pg_database { $ar_databases:
    ensure   => present,
    encoding => 'UTF8',
    require  => Class['postgresql::server']
  }

  pg_user { 'rails':
    ensure  => present,
    require => Class['postgresql::server']
  }

  pg_user { 'ubuntu':
    ensure    => present,
    superuser => true,
    require   => Class['postgresql::server']
  }

  package { 'libpq-dev':
    ensure => installed
  }

  package { 'postgresql-contrib':
    ensure  => installed,
    require => Class['postgresql::server'],
  }
}
class { 'install_postgres': }

# --- Memcached ----------------------------------------------------------------

class { 'memcached': }

# --- Packages -----------------------------------------------------------------

package { 'curl':
  ensure => installed
}

package { 'build-essential':
  ensure => installed
}

package { 'git-core':
  ensure => installed
}

# Nokogiri dependencies.
package { ['libxml2', 'libxml2-dev', 'libxslt1-dev']:
  ensure => installed
}

# ExecJS runtime.
package { 'nodejs':
  ensure => installed
}

# --- Ruby ---------------------------------------------------------------------

exec { 'install_mpapis':
  command => "${as_ubuntu} 'gpg --keyserver hkp://keys.gnupg.net --recv-keys D39DC0E3'",
  require => Package['curl']
}

exec { 'install_rvm':
  command => "${as_ubuntu} 'curl -L https://get.rvm.io | bash -s stable'",
  creates => "${home}/.rvm/bin/rvm",
  require => Exec['install_mpapis']
}

exec { 'install_ruby':
  # We run the rvm executable directly because the shell function assumes an
  # interactive environment, in particular to display messages or ask questions.
  # The rvm executable is more suitable for automated installs.
  #
  # use a ruby patch level known to have a binary
  command => "${as_ubuntu} '${home}/.rvm/bin/rvm install ruby-${ruby_version} --binary --autolibs=enabled && rvm alias create default ${ruby_version}'",
  creates => "${home}/.rvm/bin/ruby",
  require => Exec['install_rvm']
}

# RVM installs a version of bundler, but for edge Rails we want the most recent one.
exec { 'install_bundler':
  command => "${as_ubuntu} 'gem install bundler --no-rdoc --no-ri'",
  creates => "${home}/.rvm/bin/bundle",
  require => Exec['install_ruby']
}

# --- Locale -------------------------------------------------------------------

# Needed for docs generation.
exec { 'update-locale':
  command => 'update-locale LANG=en_US.UTF-8 LANGUAGE=en_US.UTF-8 LC_ALL=en_US.UTF-8'
}

# --- Run the application -------------------------------------------------------------------

# Run bundle install
exec { 'bundle_install':
  command => "${as_ubuntu} 'bundle install'",
  cwd     => '/myapp',
  require => Exec['install_bundler']
}

# Run migrations
exec { 'rake_db_create':
  command => "${as_ubuntu} 'rake db:create'",
  cwd     => '/myapp',
  require => Exec['bundle_install']
}

# Run migrations
exec { 'rake_migrate':
  command => "${as_ubuntu} 'rake db:migrate'",
  cwd     => '/myapp',
  require => Exec['rake_db_create']
}

# Starts the server
exec { 'rails_server':
  command => "${as_ubuntu} 'rvmsudo rails server -d -p 80'",
  cwd     => '/myapp',
  require => Exec['rake_migrate']
}
