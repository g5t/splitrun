#!/usr/bin/env bash
#
# Orchestrate the communication between McStas and the ECDC stack
#
# Service              | Container
# ---------------------|------------
# Kakfa                | Confluent Kafka
# Event Formation Unit | event-formation-units:latest
# Kafka-to-nexus       | [this container]
# Forwarder            | [this container]
# EPICS                | [this container]
# mcstas-EPICS         | [this container]/[user provided instrument]
# mcstas-Readout       | [this container]/[user provided instrument]
#

# Allow this bash script to use job controls:
set -m -o errexit -o pipefail -o noclobber -o nounset

# Ensure the required getopt for option handling is available:
! getopt --test >> /dev/null
if [[ ${PIPESTATUS[0]} -ne 4 ]]; then
  # shellcheck disable=SC2016
  echo '`getopt --test` failed in this environment. Install "enhanced getopt" on your system.'
  exit 1
fi

# {option}: == one required argument
OPTIONS=broker:,work:,prefix:,command:,job:
SHORT_OPTIONS=b:,w:,c:,j:
! PARSED=$(getopt --options=$SHORT_OPTIONS --longoptions=$OPTIONS --name "$0" -- "$@")
if [[ ${PIPESTATUS[0]} -ne 0 ]]; then
  # getopt complained bout wrong arguments to stdout
  exit 2
fi
eval set -- "$PARSED"

[ -z ${BROKER+x} ] && broker="broker:9092" || broker="${BROKER}"
[ -z ${WORK_DIR+x} ] && work_dir="/work" || work_dir="${WORK_DIR}"
[ -z ${WRITER_COMMAND+x} ] && writer_command="WriterCommand" || writer_command="${WRITER_COMMAND}"
[ -z ${WRITER_JOB+x} ] && writer_job="WriterJob" || writer_job="${WRITER_JOB}"
while true; do
  case "$1" in
    -b|--broker) broker="$2"; shift 2 ;;
    -w|--work) work_dir="$2"; shift 2 ;;
    -c|--command) writer_command="$2"; shift 2 ;;
    -j|--job) writer_job="$2"; shift 2 ;;
    --) shift; break ;;
    *) echo "Programming error"; exit 3 ;;
  esac
done

if [ ! -d "${work_dir}" ]; then
	echo "The requested working directory ${work_dir} does not exist, creating it inside the container"
	mkdir -p "${work_dir}"
	if [ ! -d "${work_dir}" ]; then
	  echo "Error creating working directory"
	  exit 1
  fi
fi

# Register the *required to be predefined* Kafka topics (others can be defined on the fly later)
mp-register-topics --broker "${broker}" "${writer_command}" "${writer_job}"

#echo "command-status-uri=${broker}/${writer_command}" > writer_config.txt
#echo "job-pool-uri=${broker}/${writer_job}"
# Get the list of known writers, just for logging purposes -- the two URIs are required even though they are not used
kafka-to-nexus --list_modules --command-status-uri "${broker}/${writer_command}" --job-pool-uri "${broker}/${writer_job}"
# Start a file writer
kafka-to-nexus --command-status-uri "${broker}/${writer_command}" \
               --job-pool-uri "${broker}/${writer_job}" \
               --hdf-output-prefix="${work_dir}/"\
               --verbosity trace \
               --kafka-error-timeout 10s\
               --kafka-poll-timeout 1s\
               --kafka-metadata-max-timeout 10s
               #--kafka-config consumer.timeout.ms 20000


