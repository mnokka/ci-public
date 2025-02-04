#!/bin/sh

# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2022-2023 Marko Lindqvist <marko.lindqvist@unikie.com>
# SPDX-FileCopyrightText: 2022-2023 Unikie
# SPDX-FileCopyrightText: 2022-2023 Technology Innovation Institute (TII)

# This script runs during the container setup.

hydra-init

# Initial admin user
hydra-create-user hydra --full-name 'Hydra Admin' --password "${PW_ADMIN}" --role admin

# Automation
hydra-create-user automation --full-name 'Automated Hydra Updates' --password "${PW_AUTO}" --role admin

# Shutdown postgres cleanly
pg_ctl stop -D /home/hydra/db
