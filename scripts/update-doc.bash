#!/bin/bash
#
# Generate apple doc reference documentation, update & commit gh-pages branch and push gh-pages branch to GitHub

# keep the branch we start out at. Notice that I tried to retrieve it dynamically, but it seems that Travis CI checks out latest commit with git, not the current branch, so it doesn't work that well
ORIGINAL_BRANCH=$CD_BRANCH
DOC_BRANCH="gh-pages"

# Install appledoc as its not pre-installed in Travis for some reason
curl -sL https://gist.githubusercontent.com/atsakiridis/2f8f755bd23a3e0be8dcd4aa5923d5a2/raw/1637e50d6c478add443c7cc721403a98fd72dbd5/install_appledoc.sh | sh

echo "-- Checking if repo is clean, before doing documentation generation"
is_git_repo_state_clean
if [ $? -ne 0 ]
then
	echo "-- Error: repo is not clean, please make sure that there are no untracked, unstaged or uncommitted changes"
	exit 1	
fi

echo "-- Showing local branches:"
git branch

echo "-- Original branch is: $ORIGINAL_BRANCH"
if [ "$ORIGINAL_BRANCH" == "$DOC_BRANCH" ] 
then
	echo "-- Starting off at $DOC_BRANCH which is wrong; should never trigger CI build at $DOC_BRANCH. Bailing"
	exit 1	
fi

if [ `git branch --list $DOC_BRANCH` ]
then
	echo "$DOC_BRANCH already exists, removing it"
	git branch -D $DOC_BRANCH
fi

echo "-- Checking out $DOC_BRANCH as orphan"
git checkout --orphan $DOC_BRANCH
if [ $? -ne 0 ]
then
	echo "-- Error: could not checkout: $DOC_BRANCH"
	exit 1	
fi

# When the orphan branch is created all files are staged automatically, so we need to remove them from staging area and leave them to working dir
#echo "-- Before removing unneeded files from staging area"
#git status
echo "-- Removing unneeded files from staging area"
git rm --cached -r . 
#echo "-- After removing unneeded files from staging area"
#git status

#echo "-- Rebasing $CURRENT_BRANCH to $ORIGINAL_BRANCH"
#git rebase $ORIGINAL_BRANCH
#if [ $? -ne 0 ]
#then
#	echo "-- Error: could not rebase $DOC_BRANCH to original branch. Returning to original branch and bailing"
#	git checkout $ORIGINAL_BRANCH
#	exit 1	
#fi

echo "-- Cleaning up doc output dir"
rm -fr doc/*

# Do the generation
echo "-- Generating appledoc documentation"
appledoc -h --no-create-docset --project-name "Restcomm iOS SDK" --project-company Telestax --company-id com.telestax --output "./doc" --index-desc "RestCommClient/doc/index.markdown" RestCommClient/Classes/RC* RestCommClient/Classes/RestCommClient.h

echo "-- Checking output doc dir"
find doc

# Add generated doc to staging area
echo "-- Adding newly generated doc to staging area"
git add doc/

# Commit
echo "-- Commiting to $DOC_BRANCH"
git commit -m "Update $DOC_BRANCH with Restcomm SDK Reference Documentation, Travis CI build: $TRAVIS_BUILD_NUMBER"
if [ $? -ne 0 ]
then
	echo "-- Failed to commit, bailing"
	exit 1
fi

# Need to make absolutely sure that we are in gh-pages before pushing. Originally, I tried to make this check right after 'git checkout --orphan' above, but it seems than in the orphan state the current 
# branch isn't retrieved correctly with 'git branch' because we 're in detached state
CURRENT_BRANCH=`git branch | grep \* | cut -d ' ' -f2`
echo "-- Current branch is: $CURRENT_BRANCH"
if [ "$CURRENT_BRANCH" != "$DOC_BRANCH" ] 
then
	echo "-- Error: Currently in wrong branch: $CURRENT_BRANCH instead of $DOC_BRANCH. Returning to $ORIGINAL_BRANCH and bailing"
	git checkout $ORIGINAL_BRANCH
	exit 1	
fi


echo "-- Force pushing $DOC_BRANCH to origin"
git push -f origin $DOC_BRANCH

# Old functionality, let's keep it around in case we need to use GitHub Deploy Keys in the future. 
# SSH_REPO must be set
#if [ ! -z "$SSH_REPO" ]
#then
#	echo "-- Force pushing $DOC_BRANCH to $SSH_REPO"
#	git push -f $SSH_REPO $DOC_BRANCH
#fi

# Removing non staged changes from gh-pages, so that we can go back to original branch without issues
echo "-- Removing non staged changes from $DOC_BRANCH"
git clean -fd
# TODO: Remove when fixed. There seems to be a bug in git where with the first clean, 'dependecies' dir is left intact, running it a second time removes that as well an we can resume
git clean -fd

# Debug command to verify everything is in order
git status

echo "-- Done updating docs, checking out $ORIGINAL_BRANCH"
git checkout $ORIGINAL_BRANCH
