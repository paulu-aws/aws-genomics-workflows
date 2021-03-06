#!/bin/bash
set -e

COMMAND=$1
REFERENCE_PREFIX=$2
REFERENCE_NAME=$3
SAMPLE_ID=$4
INPUT_PREFIX=$5
OUTPUT_PREFIX=${6:-$INPUT_PREFIX}

## AWS Batch places multiple jobs on an instance
## To avoid file path clobbering use the JobID and JobAttempt to create a unique path
GUID="$AWS_BATCH_JOB_ID/$AWS_BATCH_JOB_ATTEMPT"

if [ "$GUID" = "/" ]; then
    GUID=`date | md5sum | cut -d " " -f 1`
fi

REFERENCE_PATH=./$GUID/ref
INPUT_PATH=./$GUID/input
OUTPUT_PATH=./$GUID

mkdir -p $REFERENCE_PATH $INPUT_PATH

function call() {
    aws s3 cp \
        --no-progress \
        ${INPUT_PREFIX}/${SAMPLE_ID}.mpileup.vcf.gz $INPUT_PATH
    
    bcftools call \
        -m \
        --threads 16 \
        -t chr21 \
        -o $OUTPUT_PATH/${SAMPLE_ID}.vcf \
        $INPUT_PATH/${SAMPLE_ID}.mpileup.vcf.gz

    aws s3 cp \
        --no-progress \
        ${OUTPUT_PATH}/${SAMPLE_ID}.vcf $OUTPUT_PREFIX/${SAMPLE_ID}.vcf
}

function mpileup() {
    aws s3 cp \
        --no-progress \
        --recursive \
        --exclude "*" \
        --include "${REFERENCE_NAME}.fasta*" \
        ${REFERENCE_PREFIX} $REFERENCE_PATH 

    aws s3 cp \
        --no-progress \
        --recursive \
        --exclude "*" \
        --include "${SAMPLE_ID}.bam*"\
        ${INPUT_PREFIX}/ $INPUT_PATH
    
    bcftools mpileup \
        --threads 16 \
        -r chr21 \
        -Oz \
        -f $REFERENCE_PATH/${REFERENCE_NAME}.fasta \
        $INPUT_PATH/${SAMPLE_ID}.bam \
        > $OUTPUT_PATH/${SAMPLE_ID}.mpileup.vcf.gz

    aws s3 cp \
        --no-progress \
        ${OUTPUT_PATH}/${SAMPLE_ID}.mpileup.vcf.gz $OUTPUT_PREFIX/${SAMPLE_ID}.mpileup.vcf.gz
}


$COMMAND
