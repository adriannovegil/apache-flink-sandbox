#
# Makefile to manage the containers.
# Author: Adrian Novegil <adrian.novegil@gmail.com>
#
#COLORS
GREEN  := $(shell tput -Txterm setaf 2)
WHITE  := $(shell tput -Txterm setaf 7)
YELLOW := $(shell tput -Txterm setaf 3)
RED := $(shell tput -Txterm setaf 1)
RESET  := $(shell tput -Txterm sgr0)

# Add the following 'help' target to your Makefile
# And add help text after each target name starting with '\#\#'
# A category can be added with @category
HELP_FUN = \
    %help; \
    while(<>) { push @{$$help{$$2 // 'options'}}, [$$1, $$3] if /^([a-zA-Z\-]+)\s*:.*\#\#(?:@([a-zA-Z\-]+))?\s(.*)$$/ }; \
    print "usage: make [target]\n\n"; \
    for (sort keys %help) { \
    print "${WHITE}$$_:${RESET}\n"; \
    for (@{$$help{$$_}}) { \
    $$sep = " " x (32 - length $$_->[0]); \
    print "  ${YELLOW}$$_->[0]${RESET}$$sep${GREEN}$$_->[1]${RESET}\n"; \
    }; \
    print "\n"; }

JAR = user-event-count/target/streaming-job-*.jar,quickstart/target/streaming-job-*.jar

FLINK_VERSION  = 1.10.0
HADOOP_VERSION = NONE
SCALA_VERSION  = 2.12
JOB            = com.ververica.example.StreamingJob
JOB_WORDCOUNT  = com.flink.demo.WordCount
ARGS           = ''

SANDBOX_NETWORK=devsandbox
OBSERVABILITY_NETWORK=observabilitysandbox

help: ##@other Show this help.
	@perl -e '$(HELP_FUN)' $(MAKEFILE_LIST)

confirm:
	@( read -p "$(RED)Are you sure? [y/N]$(RESET): " sure && case "$$sure" in [yY]) true;; *) false;; esac )

create-network:
ifeq ($(shell docker network ls | grep ${SANDBOX_NETWORK} | wc -l),0)
	echo "Creating docker network ${SANDBOX_NETWORK}"
	@docker network create ${SANDBOX_NETWORK}
endif
ifeq ($(shell docker network ls | grep ${OBSERVABILITY_NETWORK} | wc -l),0)
	echo "Creating docker network ${OBSERVABILITY_NETWORK}"
	@docker network create ${OBSERVABILITY_NETWORK}
endif

.PHONY: jar
jar: ## Build the project jar
	cd user-event-count; mvn clean package
	cd quickstart; mvn clean package

build: jar ## Build the Docker images
	./docker/flink/build.sh --job-artifacts $(JAR) \
		--from-archive ~/Descargas/flink-$(FLINK_VERSION)-bin-scala_$(SCALA_VERSION).tgz \
		--image-name streaming-job:latest

build-from-release: ## Build the Docker images from Flink release
	./docker/flink/build.sh --job-artifacts $(JAR) \
		--from-release \
		--flink-version $(FLINK_VERSION) \
		--hadoop-version $(HADOOP_VERSION) \
		--scala-version $(SCALA_VERSION) \
		--image-name streaming-job:latest

up: create-network ## Up the image with docker-compose
	FLINK_JOB=$(JOB) FLINK_JOB_ARGUMENTS=$(ARGS) ./docker-compose-up.sh

logs-jm: ## Shows jobmanager logs
	FLINK_JOB=$(JOB) FLINK_JOB_ARGUMENTS=$(ARGS) docker-compose -f docker-compose.yml logs -f job-cluster

logs-tm: ## Shows jobmanager logs
	FLINK_JOB=$(JOB) FLINK_JOB_ARGUMENTS=$(ARGS) docker-compose -f docker-compose.yml logs -f taskmanager

status: ## Check the status of the running components
	FLINK_JOB=$(JOB) FLINK_JOB_ARGUMENTS=$(ARGS) docker-compose -f docker-compose.yml ps

ps: status ## Alias of status

down: confirm ## Down all components of the job
	FLINK_JOB=$(JOB) FLINK_JOB_ARGUMENTS=$(ARGS) docker-compose -f docker-compose.yml down -v
	@docker network rm ${SANDBOX_NETWORK} | true
	@docker network rm ${OBSERVABILITY_NETWORK} | true

clean: down ## Alias of down
