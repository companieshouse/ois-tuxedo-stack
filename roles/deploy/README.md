# Deploy role

This role implements a sequence of tasks required to deploy Tuxedo OIS services and configuration.

## Table of contents

* [Overview][1]
* [Configuration][2]
    * [Services][3]
    * [Logging][4]
    * [Maintenance jobs][5]
        * [Alerts][6]
        * [Statistics][7]

[1]: #overview
[2]: #configuration
[3]: #services
[4]: #logging
[5]: #maintenance-jobs
[6]: #alerts
[7]: #statistics

## Overview

This role encapsulates the tasks required to deploy Tuxedo services to cloud-based hosts.

## Configuration

The following sections detail the different areas of configuration supported by this role.

### Services

Tuxedo services are configured using the `tuxedo_service_config` variable. A default configuration has been provided for the full set of services expected to operate in the development, staging, and production environments. This variable is defined as a dictionary of dictionaries whose keys represent separate groups of Tuxedo services. Each group corresponds to a Linux user login and provides a level of separation between logically related services (e.g. `ceu`, `ois`, `publ`, `ceu`). It should be noted that the production environment uses three separate user accounts for services (`ceu`, `publ`, and `ceu`) whereas the staging environment combines all services into a single user account (`ois`) therefore the configuration presented by `tuxedo_service_config` is used conditionally, dependent upon the environment that the deploy role is being executed against.

Each dictionary must include the following parameters unless marked _optional_:

| Name                    | Default | Description                                                                           |
|-------------------------|---------|---------------------------------------------------------------------------------------|
| `ipc_key`               |         | A unique IPC key value for Tuxedo services.                                           |
| `local_domain_port`     |         | The port number to use for the local Tuxedo domain.                                   |
| `queue_space_ipc_key`   |         | A unique IPC key value for the primary Tuxedo queue space.                            |
| `queue_space_2_ipc_key` |         | _Optional_. A unique IPC key value for services that use a second Tuxedo queue space. |
| `tuxedo_log_size`       |         | The log size to use when creating the Tuxedo queue(s).                                |

A `tuxedo_service_users` variable is required when running this role and can be provided using the `-e|--extra-vars` option to the `ansible-playbook` command. This variable should be defined as a list of group names to be deployed, where each group name corresponds to a key in the `tuxedo_service_config` configuration variable discussed above. For example, to deploy only services belonging to the `ceu` group:

```shell
ansible-playbook -i inventory --extra-vars='{"tuxedo_service_users": ["ceu"]}'
```

### Logging

Log data can be pushed to CloudWatch log groups automatically and is controlled by the `tuxedo_log_files` configuration variable. This variable functions in a manner similar to `tuxedo_service_config` (see [Services][3]), whereby each key represents the configuration for a named group of Tuxedo services, each of which corresponds to a user account on the remote host.

`tuxedo_log_files` should be defined as a dictionary of lists whose keys represent named groups of Tuxedo services (e.g. `ois`, `xml`, `ceu` or `publ`). Each list item represents one or more log files and requires the following parameters:

| Name                        | Default | Description                                                                           |
|-----------------------------|---------|---------------------------------------------------------------------------------------|
| `file_pattern`              |         | The log file name or a file name pattern to match against. Log files are assumed to reside in `/var/log/tuxedo/<service>` where `<service>` corresponds to the dictionary key under which the list item containing this parameter is defined. |
| `cloudwatch_log_group_name` |         | The name of the CloudWatch log group that will be used when pushing log data.         |

### Maintenance jobs

The `maintenance_jobs` variable can be used to configure scheduled maintenance jobs. This is used primarily as a group variable to configure environment-specific maintenance jobs and is generally limited to the _live_ environment where alerts and statistics are required. The absence of a group variable for a given environment means that _no_ scheduled jobs will be configured.

`maintenance_jobs` should be defined as a dictionary of lists whose keys represent named groups of Tuxedo services (e.g. `ois`, `xml`, `ceu` or `publ`). Each list item represents a single scheduled job for the user matching the dictionary key under which the item is defined. The following parameters are required for each list item:

| Name                 | Default | Description                                                                          |
|----------------------|---------|--------------------------------------------------------------------------------------|
| `name`               |         | A description of the job. This parameter should be unique across all jobs defined for a given group. |
| `day_of_week`        |         | Day of the week that the job should run (`0-6` for Sunday-Saturday, `*`, and so on). |
| `day_of_month`       |         | Day of the month the job should run (`1-31`, `*`, `*/2`, and so on).                 |
| `minute`             |         | Minute when the job should run (`0-59`, `*`, `*/2`, and so on).                      |
| `hour`               |         | Hour when the job should run (`0-23`, `*`, `*/2`, and so on).                        |
| `script`             |         | The name of the script to execute. This should correspond to a script that is present in the [ois-tuxedo-scripts](https://github.com/companieshouse/ois-tuxedo-scripts) artefact being used at the time the role is executed (i.e. the archive file whose path was provided with the `scripts_artifact_path` variable when executing `ansible-playbook`).

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

During execution of this role, cron jobs are temporarily disabled to avoid generating false positive email alerts and are enabled again before completion of the role.

#### Alerts

Several of the scripts that are executed as [maintenance jobs][5] will generate email alerts dependent upon certain conditions. Alerts are _disabled_ by default and generally enabled only for the production environment. To enable alerts, define an `alerts` group variable as a dictionary with the following parameters:

| Name                 | Default | Description                                                      |
|----------------------|---------|------------------------------------------------------------------|
| `enabled`            | `no`    | The boolean value `yes` (to override the default value of `no`). |
| `vault_path`         |         | The path to the alerting configuration in Hashicorp Vault.       |

For example, to enable email alerts for the production environment add the following group variable:

```yaml
alerts:
  enabled: yes
  vault_path: "/applications/heritage-live-eu-west-2/ois-tuxedo/alerts"
```

A JSON document should be added to Hashicorp Vault at the path specified by `vault_path` with the following parameters:

| Name              | Default | Description                                                          |
|-------------------|---------|----------------------------------------------------------------------|
| `error_queues`    |         | A list of email addresses for recipients of queue alerts.            |
| `fail_check`      |         | A list of email addresses for recipients of function failure alerts. |
| `ois_status`      |         | A list of email addresses for recipients of server process alerts.   |
| `qsp_messages`    |         | A list of email addresses for recipients of QSP queue alerts.        |
| `send_blocked`    |         | A list of email addresses for recipients of blocked transfer alerts. |
| `watermark_files` |         | A list of email addresses for recipients of high watermark alerts.   |

#### Statistics

Scripts that are executed as [maintenance jobs][5] may generate statistics that require transfer to remote hosts for further processing. This is _disabled_ by default and generally enabled only for the production environment. To enable this, define a `stats` group variable as a dictionary with the following parameters:

| Name                 | Default | Description                                                      |
|----------------------|---------|------------------------------------------------------------------|
| `enabled`            | `no`    | The boolean value `yes` (to override the default value of `no`). |
| `vault_path`         |         | The path to the alerting configuration in Hashicorp Vault.       |

For example, to enable statistics for the production environment add the following group variable:

```yaml
alerts:
  enabled: yes
  vault_path: "/applications/heritage-live-eu-west-2/ois-tuxedo/stats"
```

A JSON document should be added to Hashicorp Vault at the path specified by `vault_path` with the following parameters:

| Name                 | Default | Description                                                          |
|----------------------|---------|----------------------------------------------------------------------|
| `recipients`         |         | A list of email addresses for recipients of statistical data.        |
