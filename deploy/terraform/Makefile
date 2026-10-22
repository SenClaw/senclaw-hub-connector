.PHONY: init plan apply destroy

# make apply ENV=prod TAG=0.1.0
ENV ?= prod
TAG ?=

VAR_FILE   = env/$(ENV).tfvars
STATE      = $(ENV).tfstate
EXTRA_VARS =

ifdef TAG
EXTRA_VARS += -var="image_tag=$(TAG)"
endif

init:
	terraform init

plan:
	terraform plan -var-file="$(VAR_FILE)" -state="$(STATE)" $(EXTRA_VARS)

apply:
	terraform apply -var-file="$(VAR_FILE)" -state="$(STATE)" $(EXTRA_VARS)

destroy:
	terraform destroy -var-file="$(VAR_FILE)" -state="$(STATE)" $(EXTRA_VARS)
