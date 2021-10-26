# Deploy role

This role implements a sequence of tasks required to deploy Tuxedo OIS services and configuration.

## Table of contents

* [Overview][1]
* [Configuration][2]
    * [Services][3]
    * [Logging][4]
    * [Maintenance jobs][5]

[1]: #overview
[2]: #configuration
[3]: #services
[4]: #logging
[5]: #maintenance-jobs

## Overview

This role encapsulates the tasks required to deploy Tuxedo services to cloud-based hosts.

## Configuration

The following sections detail the different areas of configuration supported by this role.

### Services

Tuxedo services are configured using the `tuxedo_service_config` variable. A default configuration has been provided for the full set of services expected to operate in the development, staging, and production environments. This variable is defined as a map of maps whose keys represent separate groups of Tuxedo services. Each group corresponds to a Linux user login and provides a level of separation between logically related services (e.g. `ceu`, `ois`, `publ`, `ceu`). It should be noted that the production environment uses three separate user accounts for services (`ceu`, `publ`, and `ceu`) whereas the staging environment combines all services into a single user account (`ois`) therefore the configuration presented by `tuxedo_service_config` is used conditionally, dependent upon the environment that the deploy role is being executed against.

Each map must include the following parameters unless marked _optional_:

| Name                    | Default | Description                                                                           |
|-------------------------|---------|---------------------------------------------------------------------------------------|
| `ipc_key`               |         | A unique IPC key value for Tuxedo services.                                           |
| `local_domain_port`     |         | The port number to use for the local Tuxedo domain.                                   |
| `queue_space_ipc_key`   |         | A unique IPC key value for the primary Tuxedo queue space.                            |
| `queue_space_2_ipc_key` |         | _Optional_. A unique IPC key value for services that use a second Tuxedo queue space. |
| `tuxedo_log_size`       |         | The log size to use when creating the Tuxedo queue(s).                                |

A `tuxedo_service_users` variable is required when running this role and can be provided using the `-e|--extra-vars` option to the `ansible-playbook` command. This variable should take the for of a list of group names that to be deployed, where each group name corresponds to a key in the `tuxedo_service_config` configuration variable discussed above. For example, to deploy only services for the `ceu` group:

```shell
ansible-playbook -i inventory --extra-vars='{"tuxedo_service_users": ["ceu"]}'
```

### Logging

Logging can be configured using the `tuxedo_log_files` configuration variable. This variable functions in a manner similar to `tuxedo_service_config` (see [Services][1]), whereby each key represents the configuration for a named group of Tuxedo services that correspond to a user account on the remote host. Each key should contain a list of maps

`maintenance_jobs` should be defined as a dictionary of lists whose keys represent Tuxedo service users (e.g. `ois`, `xml`, `ceu` or `publ`). Each list item represents a log file and requires the following parameters:

| Name                        | Default | Description                                                                           |
|-----------------------------|---------|---------------------------------------------------------------------------------------|
| `file_pattern`              |         | The log file name or a pattern to match against. Log files are assumed to reside in `/var/log/tuxedo/<service>` where `<service>` corresponds to the map key under which the list item containing this parameter is present. |
| `cloudwatch_log_group_name` |         | The CloudWatch log group that will be used when pushing log data.                     |

### Maintenance jobs

The `maintenance_jobs` variable can be used to configure scheduled maintenance jobs. This is used primarily as a group variable to configure environment-specific maintenance jobs, and is generally limited to the _live_ environment for generating alerts and statistics. The absence of this variable for a given environment means that _no_ scheduled jobs will be configured.

`maintenance_jobs` should be defined as a dictionary of lists whose keys represent Tuxedo service users (e.g. `ois`, `xml`, `ceu` or `publ`). Each list item represents a scheduled job for a given Tuxedo service user and requires the following parameters:

| Name                 | Default | Description                                                                          |
|----------------------|---------|--------------------------------------------------------------------------------------|
| `name`               |         | A short description of the job.                                                      |
| `day_of_week`        |         | Day of the week that the job should run (`0-6` for Sunday-Saturday, `*`, and so on). |
| `day_of_month`       |         | Day of the month the job should run (`1-31`, `*`, `*/2`, and so on).                 |
| `minute`             |         | Minute when the job should run (`0-59`, `*`, `*/2`, and so on).                      |
| `hour`               |         | Hour when the job should run (`0-23`, `*`, `*/2`, and so on).                        |
| `script`             |         | The name of the script to execute. This should  [ois-tuxedo-scripts](https://github.com/companieshouse/ois-tuxedo-scripts) build artifact to be executed. Mutually exclusive with `job`.

For example, to execute the `ois_status` script every minute of every day as the `ois` user:

```yaml
maintenance_jobs:
  ois:
    - name: Server status alert
      day_of_week: "*"
      day_of_month: "*"
      minute: "*"
      hour: "*"
      script: "ois_status"
```

During the `deploy` play, cron jobs are disabled (i.e. removed) early in the play to avoid generating false positive email alerts and enabled again at the end of the play.
