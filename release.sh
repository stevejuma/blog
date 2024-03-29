#!/usr/bin/env sh
set -e
set -o pipefail

# Print a usage message and exit.
usage() {
	echo "Missing $1"
	cat >&2 <<-'EOF'
	To run, I need:
	- to be in a container generated by the Dockerfile at the top of the Docker
	repository;
	- to be provided with the name of an S3 bucket, in environment variable
	AWS_S3_BUCKET;
	- to be provided with AWS credentials for this S3 bucket, in environment
	variables AWS_ACCESS_KEY and AWS_SECRET_KEY;
	- a generous amount of good will and nice manners.
	The canonical way to run me is to run the image produced by the Dockerfile: e.g.:"
	docker run -e AWS_S3_BUCKET=docker.party \
		-e AWS_ACCESS_KEY=... \
		-e AWS_SECRET_KEY=... \
		-it \
		stevejuma/blog ./release.sh
	EOF
	exit 1
}


echo "Building site with hugo"
hugo

if [ ! -d public ]; then
	echo "Something went wrong we should have a public folder."
fi

[ "$AWS_S3_BUCKET" ]  || usage "AWS_S3_BUCKET"
[ "$AWS_ACCESS_KEY" ] || usage "AWS_ACCESS_KEY"
[ "$AWS_SECRET_KEY" ] || usage "AWS_SECRET_KEY"

# enter public
cd public

# upload the files to s3
s3cmd sync --delete-removed -P . s3://$AWS_S3_BUCKET/