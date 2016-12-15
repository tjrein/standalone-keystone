#!/bin/env ruby

$mysql_password = "password"
$rabbit_password = "password"

$environment_vars = [ 
  'OS_USERNAME=admin', 
  'OS_PASSWORD=password', 
  'OS_AUTH_URL=http://controller:35357/v3',
  'OS_PROJECT_NAME=admin', 
  'OS_USER_DOMAIN_NAME=default', 
  'OS_PROJECT_DOMAIN_NAME=default', 
  'OS_IDENTITY_API_VERSION=3' 
]

package { "mariadb-server": ensure => installed }
package { "python-pymysql": ensure => installed }
package { "expect": ensure => installed }
package {"rabbitmq-server": ensure => installed }

exec { 'rabbitmq_add_openstack_user':
  command => "/usr/sbin/rabbitmqctl add_user openstack ${rabbit_password}",
  require => Package['rabbitmq-server'] 
}

exec { 'configure_rabbitmq_access':
  command => "/usr/sbin/rabbitmqctl set_permissions openstack '.*' '.*' '.*'",
  require => [ Package['rabbitmq-server'],
               Exec['rabbitmq_add_openstack_user'] ]
}

file { '/vagrant/99-openstack.cnf':
  ensure => file,
  owner  => 'root',
  group  => 'root',
  path   => '/vagrant/99-openstack.cnf',
  mode   => '0755'
}

exec { 'cp-environment':
  command => '/bin/cp /vagrant/environment /etc/environment'
}

exec { 'cp-mysql-cnf':
  command => '/bin/cp /vagrant/99-openstack.cnf /etc/mysql/mariadb.conf.d/99-openstack.cnf',
  require => File['/vagrant/99-openstack.cnf']
}

exec { 'restart_mysql':
  command => '/usr/sbin/service mysql restart',
  require => Exec['cp-mysql-cnf'] 
}

exec { 'run_my_script':
  command => '/bin/bash -c "/vagrant/mysql_secure.sh"',
  require => Exec['restart_mysql']
}

exec { "create-keystone-db":
  command => "/usr/bin/mysql -u root -ppassword -e \"CREATE DATABASE keystone; \
             GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY 'password'; \
             GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY 'password';\"",
  require => [ Package['mariadb-server'],
               Package['python-pymysql'],
               Exec['run_my_script']]
}  

exec { "install_keystone":
  command => "/usr/bin/apt install keystone",
  require => Exec["create-keystone-db"]
}

file_line { 'edit_sql_connection':
  path  => '/etc/keystone/keystone.conf',
  line  => "connection = mysql+pymysql://keystone:${mysql_password}@controller/keystone",
  match => 'connection = sqlite:////var/lib/keystone/keystone.db',
  before => Exec['populate_identity_database'],
  require => Exec['install_keystone']
}

file_line { 'edit_token':
  path => '/etc/keystone/keystone.conf',
  line => "\nprovider = fernet",
  after => "^\[token\]$",
  before => Exec['populate_identity_database'],
  require => Exec['install_keystone']
}

exec { "populate_identity_database":
  command => '/bin/su -s /bin/sh -c "keystone-manage db_sync" keystone',
  require => Exec['install_keystone']
}

exec { "fernet_setup":
  command => '/usr/bin/keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone',
  require => Exec['populate_identity_database']
}

exec { "credential_setup":
  command => '/usr/bin/keystone-manage credential_setup --keystone-user keystone --keystone-group keystone',
  require => Exec['fernet_setup']
}

exec { 'bootstrap_keystone':
  command => '/usr/bin/keystone-manage bootstrap --bootstrap-password password \
             --bootstrap-admin-url http://controller:35357/v3/ \
             --bootstrap-internal-url http://controller:35357/v3/ \
             --bootstrap-public-url http://controller:5000/v3/ \
             --bootstrap-region-id RegionOne',
  require => Exec['credential_setup']
}

file_line { 'add_controller_name':
  path => '/etc/apache2/apache2.conf',
  line => "\nServerName controller",
  before => Exec['restart_apache2']
}

exec { 'restart_apache2':
  command => '/usr/sbin/service apache2 restart',
  require => Exec['bootstrap_keystone']
}

exec { 'create_project':
  environment => $environment_vars,
  command => '/usr/bin/openstack project create --domain default \
             --description "Service Project" service',
  require => Exec['restart_apache2']
}

exec { 'create_demo_project':
  environment => $environment_vars,
  command => '/usr/bin/openstack project create --domain default \
             --description "Demo Project" demo',
  require => Exec['restart_apache2']
}

exec { 'create_demo_user':
  environment => $environment_vars,
  command => '/usr/bin/openstack user create --domain default --password password demo',
  require => Exec['create_demo_project']
}

exec { 'create_user_role':
  environment => $environment_vars,
  command => '/usr/bin/openstack role create user',
  require => Exec['restart_apache2']
}

exec { 'add_role_to_user':
  environment => $environment_vars,
  command => '/usr/bin/openstack role add --project demo --user demo user',
  require => [ Exec['create_demo_user'], 
               Exec['create_user_role'] ]
}
