# ois-tuxedo-stack

This project encapsulates the infrastructure and deployment code for OIS Tuxedo services and includes separate branches for each:

* `infrastructure` - Infrastructure code for building OIS Tuxedo services in AWS
* `deployment` - Deployment code for deploying OIS Tuxedo services to AWS

The remainder of this document contains information that is specific to the branch in which it appears.

## Deployment

This branch (i.e. `deployment`) contains the deployment code responsible for deploying OIS Tuxedo services and is composed of a single Ansible role named `deploy` which is used primarily in CI to deploy groups of OIS Tuxedo services to a given environment.

Refer to the [role documentation](roles/deploy/README.md) for further information.

