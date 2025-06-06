# Overview
---

This scripted solution performs stackset to stackset CloudFormation stack instance migrations.  It deletes and retains the stack instance(s) from the source stackset.  It then waits for completion prior to importing the stack instances into the target stackset.  Once completed, it runs a stackset update on the target stackset to ensure consistency with the imported stacks.  The assumption is that you have an empty stackset with a matching template targeting an empty OU.  The script is designed to be used for Landing Zone pipeline to Customizations for Control Tower pipeline migration activities, but can serve other uses where it is necessary to migrate stack instances from one stackset to another.

## migrate_pagination.sh
---

This script is the primary script for the solution and performs the stackset migration actions referenced in the 'Overview' section above.  This script requires several inputs as follows:

**SOURCE_STACK_SET_NAME** - The name of the source CloudFormation StackSet.  Required to perform a migration action.
**TARGET_STACK_SET_NAME** - The name of the target CloudFormation StackSet.  Required to perform a migration action.
**CLOUDFORMATION_ADMIN_ROLE_ARN** - The ARN of the CloudFormation admin role ARN.  Required to perform a migration action.  
**CLOUDFORMATION_EXECUTION_ROLE_NAME** - The name of the CloudFormation execution role.  Required to perform a migration action.
**SOURCE_STACK_SET_REGIONS** - A list of regions to delete the source stack instances from.  Required to delete stack instances from the source stack set.
**SOURCE_STACK_ACCOUNT_LIST** - A specific list of account IDs for the source StackSet.  Allows limiting the migration to a subset of specific stacks in the stackset.  If a list of account IDs is specified for this input, only those stack instances that correspond to the account IDs and the regions from the previous input will be migrated.  If this field is not provided, all stack instances from the source stackset will be migrated regardless of their account association.

#### Please note, while using this script there is one small catch, there shouldn't be any tags attached to the target StackSet

## continue_import_stack_instance.sh
---
In case the session times out while running the above script, as it imports 10 stack instances at a time, one can use the following script by using the command mentioned below, which will help you to start the import of the stack instances.

```
./continue_import_stack_instance.sh <target-stackset-name> <primary-region>
```

## status_report.sh
---

This script provides a basic reporting functionality to check the status and the status reason for the migrated stack instances.  This script requires two inputs as follows:

**SOURCE_STACK_SET_NAME** - The name of the source CloudFormation StackSet.  Required to perform the reporting action.
**TARGET_STACK_SET_NAME** - The name of the target CloudFormation StackSet.  Required to perform the reporting action.
**PRIMARY_REGION** - The name of the primary region.  Required for script execution.  If not provided, the script will check the artifact source_region_list.txt file from the migrate.sh script artifacts folder for the specified source stackset.  If a primary region is not provided manually or not determined from the source file, the script will exit.

**Please read the rest of this document prior to using these scripts.**

## Usage
---

### Perform a stackset migration
---

#### Run the command as seen below to execute the migrate script:

'''

./migrate_pagination.sh [SOURCE_STACK_SET_NAME] [TARGET_STACK_SET_NAME] [CLOUDFORMATION_ADMIN_ROLE_ARN] [CLOUDFORMATION_EXECUTION_ROLE_NAME] [SOURCE_STACK_SET_REGIONS] [SOURCE_STACK_ACCOUNT_LIST]

'''

Sample Command:
```
./migrate_pagination.sh \
  "source-stack-set-name" \
  "target-stack-set-name" \
  "arn:aws:iam::123456789012:role/CloudFormationAdminRole" \
  "CloudFormationExecutionRole" \
  "us-east-1 us-west-2" \
  "111111111111,222222222222"
```

In the above command, the first region mentioned is always the primary/home region

### Report status for a completed migration action
---

#### Run the command as seen below to execute the status report script:

This command creates a CSV report file in the artifact folder having the same name as the source stackset.  The CSV file is appended for each stack instance status that was migrated.  The script requires an artifact from the migrate.sh script.  The following input and output files are expected:

INPUTFILE = ./artifacts/$SOURCE_STACK_SET_NAME/source_migration_list.txt
OUTPUTFILE = ./artifacts/$SOURCE_STACK_SET_NAME/$SOURCE_STACK_SET_NAME-to-$TARGET_STACK_SET_NAME-status-report.csv

Change the INPUTFILE field on line 48 of the script to specify a list of ARNs other than the artifact from the migrate.sh script execution.

'''

./status_report.sh [SOURCE_STACK_SET_NAME] [TARGET_STACK_SET_NAME] [PRIMARY_REGION]

'''


### Report on all migrated stacksets

#### Run the command as seen below to execute the migrate script:

This command is useful to report the stack status for all stack instance migrated as part of a migration activity.  The resulting output is a series of CSV reports generated in the output artifact folders corresponding to the name of the migrated source stack instance.  

'''

./check-all-stacks.sh

'''

Make sure to edit the above file and add the specific names of the stacksets you migrated using the migrate-all-stacksets.sh script.
