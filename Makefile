.PHONY: release clean clean-venv venv install clean-test-db validate

# by default, we settle down in this region
AWS_REGION ?= eu-west-3

ifeq ($(CURRENT_BRANCH), main)
	environment = dev
else
	environment = $(CURRENT_BRANCH)
endif

ifeq ($(CURRENT_BRANCH),prod)
	S3_BUCKET = digidocs-artifacts-bucket-prod
else
	S3_BUCKET = digidocs-artifacts-bucket-dev
endif



clean:
	rm -rf build .coverage .python-version *egg-info .pytest_cache

clean-venv:
	rm -rf .venv

venv: clean-venv clean
	virtualenv --python=python312 .venv

install: 
	@echo "Installing dependencies for " ${environment}
	.venv/bin/pip install --upgrade pip setuptools
	.venv/bin/pip install -r requirements.txt

test:
	.venv/bin/pytest -x --junitxml=reports/test-unit.xml --cov-report xml:cobertura.xml --cov-report term-missing --cov-report html --cov=backend --color=yes

serve:
	.venv/bin/fastapi dev src/main.py
run:
	.venv/bin/python run.py

deploy-buckets:
	aws cloudformation deploy \
		--template-file infrastructure/buckets.yaml \
		--region ${AWS_REGION} \
		--stack-name "digidocs-global-buckets-${env}" \
		--parameter-overrides EnvironmentName=${env} \
		--capabilities CAPABILITY_NAMED_IAM \
		--tags "Application=Digidocs" \
		--no-fail-on-empty-changeset
	@echo "API Endpoint - GraphQL URL:"
	aws cloudformation describe-stacks \
				--stack-name "digidocs-global-buckets-${env}" \
				--region ${AWS_REGION} \
				--query 'Stacks[0].Outputs[?OutputKey==`DigidocsGeneralBucketName`].OutputValue' --output text

build-digidocs-api:
	@echo "Consolidating python code in ./digidocs_build"
	mkdir -p digidocs_build
	rm -rf digidocs_build/
	.venv/bin/pip install  --disable-pip-version-check -r requirements.txt -t digidocs_build/
	cp -R src digidocs_build/
	@echo "Package and upload by Cloudformation"
	aws cloudformation package \
				--template-file infrastructure/lambda-digidocs.yaml \
				--s3-bucket ${S3_BUCKET} \
				--s3-prefix "digidocs-api-lambda-artifacts" \
				--output-template-file digidocs_build/template-lambda.yaml \

deploy-digidocs-api:
	aws cloudformation deploy \
		--template-file digidocs_build/template-lambda.yaml \
		--region ${AWS_REGION} \
		--stack-name "digidocs-api-${environment}" \
		--parameter-overrides EnvironmentName=${environment} \
		--capabilities CAPABILITY_IAM \
		--no-fail-on-empty-changeset
	@echo "API Endpoint:"
	aws cloudformation describe-stacks \
				--stack-name "digidocs-api-${environment}" \
				--region ${AWS_REGION} \
				--query 'Stacks[0].Outputs[?OutputKey==`DigidocsApiUrl`].OutputValue' --output text


deploy-cognito:
	aws cloudformation deploy \
		--template-file infrastructure/cognito.yaml \
		--region ${AWS_REGION} \
		--stack-name "digidocs-cognito-${environment}" \
		--parameter-overrides EnvironmentName=${environment} CognitoDomain=digidocs-domain-${environment} \
		--capabilities CAPABILITY_NAMED_IAM \
		--tags "Application=Digidocs" \
		--no-fail-on-empty-changeset
	aws cloudformation describe-stacks \
				--stack-name "digidocs-cognito-${environment}" \
				--region ${AWS_REGION} \
				--query 'Stacks[0].Outputs[?OutputKey==`UserPoolId`].OutputValue' --output text
	aws cloudformation describe-stacks \
				--stack-name "digidocs-cognito-${environment}" \
				--region ${AWS_REGION} \
				--query 'Stacks[0].Outputs[?OutputKey==`UserPoolClientId`].OutputValue' --output text
	aws cloudformation describe-stacks \
				--stack-name "digidocs-cognito-${environment}" \
				--region ${AWS_REGION} \
				--query 'Stacks[0].Outputs[?OutputKey==`UserPoolDomain`].OutputValue' --output text

validate:
	sam validate -t infrastructure/lambda-digidocs.yaml --region eu-west-3 --lint
	aws cloudformation validate-template --template-body file://infrastructure/lambda-digidocs.yaml

build:
	@echo "Consolidating python code in ./digidocs_build"
	rm -rf digidocs_build/
	mkdir -p digidocs_build
	cp requirements.txt digidocs_build/
	cp .env digidocs_build/
	cp -R src digidocs_build/
	sam build --use-container -t infrastructure/lambda-digidocs.yaml

deploy:
	@echo "Deploying to " ${environment}
	sam deploy --resolve-s3 --template-file .aws-sam/build/template.yaml --stack-name "digidocs-api-stack-${environment}" \
         --capabilities CAPABILITY_IAM --region ${AWS_REGION} --parameter-overrides EnvironmentName=${environment} --no-fail-on-empty-changeset
	rm -rf digidocs_build/

deploy-local:
	sam local start-api


show_variables:
	echo ${env}
	echo $(JENKINS_EMAIL) $(CURRENT_VERSION) $(CURRENT_BRANCH)
