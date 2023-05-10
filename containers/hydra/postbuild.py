#!/usr/bin/env nix-shell
#!nix-shell -i python3 -p "python3.withPackages(ps: [ ps.slackclient ])"
#
#



# ------------------------------------------------------------------------
# SPDX-License-Identifier: Apache-2.0
# SPDX-FileCopyrightText: 2023 Tero Tervala <tero.tervala@unikie.com>
# SPDX-FileCopyrightText: 2023 Unikie
# SPDX-FileCopyrightText: 2023 Technology Innovation Institute (TII)
# ------------------------------------------------------------------------
# Hydra post build hook script
#
# Creates build information json file and a symbolic link to the image file
# with human understandable name.
# ------------------------------------------------------------------------

# de/activate Slack messaging possibility (ON/OFF). See Readme for needed configurations in Slack application
# TBD dockerfile 
SLACKING="ON"

import sys
import json
import os
import tempfile
import subprocess
if (SLACKING=="ON"):
    import slack    

# ------------------------------------------------------------------------
# Global variables
# ------------------------------------------------------------------------
imagefn = "nixos.img"
nixstore = "nix-store"
linksuffix = "-nixos.img"
infosuffix = "-build-info.json"
slacktoken = "not_yet_defined"


# ------------------------------------------------------------------------
# Prints an error message and exits
# txt = Error message
# code = optional exit code
# ------------------------------------------------------------------------
def perror(txt, code=1):
    channel=ghaf-build
    mytoken=xoxb-1365182781681-5066343583492-vTznjo2NBzqIr1yynUjECZSB
    print(txt, file=sys.stderr)
    if (SLACKING=="ON"):
        slack(channel,txt,mytoken)
    sys.exit(code)

# ------------------------------------------------------------------------
# Prints an error message to chosen Slack channel
# slackchannel = Slack channel (configured and app installed in Slack)
# slackmessage = Message to be printed
# slacktoken = Slack provied token for application usage (got vie env variable, global)
# ------------------------------------------------------------------------
def slack(slackchannel,slackmessage,slacktoken):
    if (SLACKING=="ON"):
            
        try:
            client = slack.WebClient(token=slacktoken)
            client.chat_postMessage(channel=slackchannel, text=slackmessage)

        except Exception as e:
            print(("Slacking failed! Check your channel name?, error: %s" % e))
            sys.exit(1)
    

# ------------------------------------------------------------------------
# Add given path to nix store
# path = path to file/dir to be added
# returns nix store path for added file/dir
# ------------------------------------------------------------------------
def nix_store_add(path: str) -> str:
    result = subprocess.run([nixstore, '--add', path], stdout=subprocess.PIPE)

    if result.returncode != 0:
        perror(f"{nixstore} --add {path} failed ({result.returncode}):\n{result.stderr.decode('utf-8')}")

    return result.stdout.decode('utf-8').strip()


# ------------------------------------------------------------------------
# Remove given path from nix store (if it exists, no error if nonexistent)
# path = nix store path to remove
# ------------------------------------------------------------------------
def nix_store_del(path: str):
    if os.path.exists(path):
        result = subprocess.run([nixstore, '--delete', path], stdout=subprocess.PIPE)

        if result.returncode != 0:
            perror(f"{nixstore} --delete {path} failed ({result.returncode}):\n{result.stderr.decode('utf-8')}")


# ------------------------------------------------------------------------
# Main program
# ------------------------------------------------------------------------
def main(argv: list[str]):
    # Declare as globals just in case
    global imagefn
    global nixstore
    global linksuffix
    global infosuffix
    if (SLACKING):
        global slacktoken

    # HYDRA_JSON is set by Hydra to point to build information .json file
    jsonfn = os.getenv("HYDRA_JSON")
    if jsonfn == None:
        perror("HYDRA_JSON not defined")

    # POSTBUILD_SERVER needs to be set to the current server (e.g. hydra or awsarm)
    hydra = os.getenv("POSTBUILD_SERVER")
    if hydra == None:
        perror("POSTBUILD_SERVER not defined")

    # Allow override of the default nix-store command
    nixstore = os.getenv("POSTBUILD_NIXSTORE", nixstore)

    # Allow override of the default image file name
    imagefn = os.getenv("POSTBUILD_IMAGE", imagefn)

    # Allow override of the default image link suffix
    linksuffix = os.getenv("POSTBUILD_LINKSUFFIX", linksuffix)

    # Allow override of the default info file suffix
    infosuffix = os.getenv("POSTBUILD_INFOSUFFIX", infosuffix)

    #if (SLACKING=="ON"):
    #    if 'SLACKTOKEN' in os.environ:
    #        slacktoken=(os.environ['SLACKTOKEN'])
    #    else:
    #        perror("Slacking activated but no SLACKTOKEN env variable found. Not able to Slack this error")
        

    # Load build information
    with open(jsonfn) as jsonf:
        binfo = json.load(jsonf)

    # Check status of the build, we are interested only in finished builds
    if binfo['buildStatus'] != 0 or binfo['finished'] != True or binfo['event'] != "buildFinished":
        perror("Unexpected build status")
    else: 
        perror ("OK build status")

    # Find output path
    outp = None
    for output in binfo['outputs']:
        if output['name'] == 'out':
            outp = output['path']

    if outp == None:
        perror("Output not found")

    imgf = outp + "/" + imagefn

    # Check that output image file exists
    if not os.path.isfile(imgf):
        perror(f"{imgf} not found")

    target = binfo['job'].split('.')[0]
    build = binfo['build']
    linkname = f"{target}{linksuffix}"
    infoname = f"{hydra}-{build}{infosuffix}"

    # Create link and info file in a temporary directory
    with tempfile.TemporaryDirectory() as tmpdir:
        linkfn = f"{tmpdir}/{linkname}"
        infofn = f"{tmpdir}/{infoname}"

        # Create symlink to image and add it to nix store
        os.symlink(imgf, linkfn)
        niximglink = nix_store_add(linkfn)

        print(f'POSTBUILD_LINK="{niximglink}"')

        # Add symlink info also to build information
        binfo['imageLink'] = niximglink

        # Write build information to build info file and add to nix store
        with open(infofn, "w") as infof:
            json.dump(binfo, infof)

        nixbuildinfo = nix_store_add(infofn)

        # Print the build-info nix store path so that it can be scraped
        # from Hydra web ui run command logs automatically.
        print(f'POSTBUILD_INFO="{nixbuildinfo}"')


# ------------------------------------------------------------------------
# Run main when executed from command line
# ------------------------------------------------------------------------
if __name__ == "__main__":
    main(sys.argv)
