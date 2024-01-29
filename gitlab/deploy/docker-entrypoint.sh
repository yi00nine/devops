#!/bin/bash

set -eo pipefail
shopt -s nullglob

services=("CLEANING" "BACKEND" "LABEL"  "SYNC" "COMMON" "DUPLICATION" "TRANSFORMER" "NODE_MANAGEMENT")
actions=("webserver" "celery")
queues=("CELERY_CLEANING_QUEUE" "CELERY_LABEL_QUEUE" "CELERY_SYNC_QUEUE" "CELERY_COMMON_QUEUE" "CELERY_DUPLICATION_QUEUE", "CELERY_TRANSFORMER_QUEUE")

for ((i=0; i<${#services[@]}; i++))
do
  service=${services[i]}
  service_variable="${service}_SERVICE_NAME"
  assembled_service="${!service_variable}"
  home_variable="${service}_HOME"
  assembled_home="${!home_variable}"
  for action in "${actions[@]}"
  do
    case $1 in
      ${assembled_service})
        case $2 in
          "webserver")
            cd ${assembled_home}
            echo "$1: starting webserver, listening on 80 ..."
            uvicorn app:app --host 0.0.0.0 --port 80
            ;;
          "celery")
            cd ${assembled_home}
            echo "$1: starting celery worker..."
            export C_FORCE_ROOT="true"
            celery -A app.worker.task worker -c 1 -Q ${CELERY_QUEUE_NAME}
            ;;
          *)
            echo "service $1 has no action of $2"
            echo "valid actions are: webserver, migrate, celery"
            exit 1
            ;;
        esac
        ;;
    esac
  done
done
case $1 in
  ${BFF_SERVICE_NAME})
    case $2 in
      "webserver")
        echo "$1: starting webserver, listening on ${HTTP_PORT}..."
        cd ${BFF_HOME}
        node main.bundle.js
        ;;
      *)
        echo "service $1 has no action of $2"
        echo "valid actions are: nginx, webserver, start-all"
        exit 1
        ;;
    esac
    ;;
  
  ${UDS_SERVICE_NAME})
    case $2 in
      "webserver")
        echo "$1: starting uds_service, listening on ${HTTP_PORT}..."
        cd ${UDS_HOME}
        java -jar uds.jar
        ;;
      *)
        echo "service $1 has no action of $2"
        echo "valid actions are: nginx, webserver, start-all"
        exit 1
        ;;
    esac
    ;;

  "/bin/bash")
    echo "debug mode: starting bash shell"
    ;;

  *)
    echo "service $1 does not exist"
    echo "usage: $0 <service> <action>"
    exit 1
    ;;

esac

exec "$@"
