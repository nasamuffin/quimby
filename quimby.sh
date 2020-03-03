#!/bin/bash

# Author: nasamuffin
#
# Usage:
#
#   quimby [-v <version>] [--rfc] [-o <path>] <base-branch> <topic-branch>
#
# When you invoke 'quimby' against your topic, it does the following things:
#
# 1) Pushes (by force if necessary) <topic-branch> and <base-branch> to your
#    fork of Git on Github.
# 2) If one doesn't already exist, opens a PR against GitGitGadget for
#    <topic-branch>, based on <base-branch> as GitGitGadget knows it.
# 3) Calls 'git-format-patch' with the provided flags, plus --cover-letter if
#    more than one commit will exist.
# 4) Tells you where your mails went, and hands you a link to the PR.
#
# quimby relies on git of course, and on the Github CLI 'gh'.
#
# Some notes:
#
# - <base-branch> must be a branch which is mirrored by GitGitGadget. That means
#   it could be any branch which exists in gitster/git.
# - <topic-branch> will be force-pushed to your own fork. If you're using quimby
#   because your usual workflow doesn't use Github at all, that shouldn't bother
#   you.

QUIMBY_BODY="\
This pull request was created by https://github.com/nasamuffin/quimby, a tool \
for Git contributors who are accustomed to a git-format-patch/git-send-email \
workflow but want to see the GitGitGadget CI run results. It should probably \
be ignored!"

# Positional parameters
PARAMS=()

version_flag=
rfc_flag=
output_flag=


# Check for args
while (( "$#" )); do
  case "$1" in
    -v)
      version_flag="-v$2"
      shift 2
      ;;
    --rfc)
      rfc_flag="--rfc"
      shift
      ;;
    -o)
      output_path="$2"
      shift 2
      ;;
    *)
      PARAMS+=("$1")
      shift
      ;;
  esac
done

if [[ "${#PARAMS[@]}" -ne 2 ]];
then
  # todo echo usage
  echo " quimby [-v <version>] [--rfc] [-o <path>] <base-branch> <topic-branch>"
  exit
fi

base_branch="${PARAMS[0]}"
topic_branch="${PARAMS[1]}"
subject="[QUIMBY] CI run for ${topic_branch} on top of ${base_branch}"

if [[ -z "${output_path}" ]];
then
  output_path="${PWD}"
fi

# Sneakily, grab the GH username iff a PR already exists.
# This is hacky!!! It relies on user-targeted output!!! 'gh' seems ill-suited
# for scripting. :(
user_name="$(gh -R gitgitgadget/git pr status | grep ":${topic_branch}\]" |
  grep -v "no pull request" | uniq |
  sed -e 's/.*\[\(.*\):'"${topic_branch}"'\]/\1/')"

# Check if PR exists on GGG
if [[ -z "${user_name}" ]];
then
  gh -R gitgitgadget/git pr create -d -B "${base_branch#gitster/}" -t "${subject}" \
    -b "${QUIMBY_BODY}"
else
  git push "ssh://git@github.com/${user_name}/git" "${base_branch}" +"${topic_branch}"
fi

# Determine whether a cover letter is needed
cover_letter_flag=
if [[ "$(git rev-list --count "${base_branch}..${topic_branch}")" -gt 1 ]];
then
  cover_letter_flag="--cover-letter"
fi

git format-patch ${version_flag} ${rfc_flag} -o "${output_path}" \
  ${cover_letter_flag} "${base_branch}..${topic_branch}"
