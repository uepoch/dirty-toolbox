#!/usr/bin/bash -e

usage() {
	echo "Usage:" >&2
	echo "$0 -f CONSUL_SNAPSHOT -t CONSUL_ACL_TOKEN -p CONSUL_PORT -o OUTFILE -k PREFIX" >&2
	echo "You can provide them as environment variable" >&2
	echo ""
	echo "Purpose:"
	echo "This script was made to extract the kv tree present in a consul snapshot"
}

poison_pill() {
	pkill -P $$
}

while getopts ":f:t:p:o:k:h" opt
do
	case $opt in 
	   f)
		   CONSUL_SNAPSHOT=$OPTARG
		   #echo "Found $OPTARG in f"
		   ;;
	   t)
		   CONSUL_ACL_TOKEN=$OPTARG
		   #echo "Found $OPTARG in t"
		   ;;
	   p) 
		   CONSUL_PORT=$OPTARG
		   #echo "Found $OPTARG in p"
		   ;;
	   o)
		   OUTFILE=$OPTARG
		   ;;
	   k)
		   PREFIX=$OPTARG
		   ;;
	   h)
		   usage
		   exit 0
		   ;;
	   \?)
		   echo "Unknown arg $OPTARG" >&2
		   usage
		   exit 2
		   ;;
	   :)
		   echo "Parameter $OPTARG requires a value !" >&2 
		   usage
		   exit 2
		   ;;
   esac
done

if [ -z "$CONSUL_SNAPSHOT" ]; then
	usage
	exit 1
fi

CONSUL_PORT=${CONSUL_PORT:-32123}
OUTFILE=${OUTFILE:-./kv.json}

if ! command -v "consul" >/dev/null ; then
	echo "You must install consul first"
	return
fi

if ! [ -f "${CONSUL_SNAPSHOT}" ] || [ "$(file -biz ${CONSUL_SNAPSHOT})" != "application/x-tar; charset=binary compressed-encoding=application/x-gzip; charset=binary" ]; then
	echo "The ${CONSUL_SNAPSHOT} file does not seem to be a valid snapshot"
fi

dir=$(mktemp -d)

consul agent -dev -server -http-port=${CONSUL_PORT} -dns-port=-1 -advertise=127.0.0.1 -bind=127.0.0.1 -client=127.0.0.1 &>/dev/null &

trap poison_pill EXIT

sleep 1

consul snapshot restore -http-addr="127.0.0.1:$CONSUL_PORT" "$CONSUL_SNAPSHOT"
consul kv export -http-addr=127.0.0.1:"$CONSUL_PORT" $PREFIX > "${OUTFILE}"

poison_pill
