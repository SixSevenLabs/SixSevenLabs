package main

import (
	"context"
	"log"
	"fmt"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/aws/aws-lambda-go/lambda"
	"github.com/aws/aws-sdk-go-v2/service/sts"
	"github.com/aws/aws-sdk-go-v2/credentials/stscreds"

	"github.com/sixsevenlabs/sixsevenlabs/backend/master/internal/bin"
	"github.com/sixsevenlabs/sixsevenlabs/backend/master/internal/fetch"
	"github.com/sixsevenlabs/sixsevenlabs/backend/master/internal/types"
)

// master lambda function: implements bin packing algorithm for splitting up data into chunks

// domain (assumes a valid "job" requested and does not care about status of job after):
// - fetching object keys from s3
// - checking job status (to check if new job or already runinng but this depends on how we want to handle data)
// - job status: queued, running, failed, completed
// - splitting up data into chunks
// - calling augmentor lambda
// - job status stuff 

const (
	DESIRED_BIN_SIZE       int64 = 128 * 1024 * 1024 // 128mb
	ABSOLUTE_MAX_FILE_SIZE int64 = 256 * 1024 * 1024 // 256mb
	MAX_CONCURRENT_WORKERS int   = 40                // step functions map state max concurrency
)

func validateInput(req types.LambdaRequest) error {
	if req.S3Bucket == "" {
		return fmt.Errorf("s3_bucket is required")
	}
	if req.CustomerRoleARN == "" {
		return fmt.Errorf("customer_role_arn is required")
	}
	if len(req.Rules) == 0 {
		return fmt.Errorf("rules are required")
	}
	return nil
}

func HandleRequest(ctx context.Context, req types.LambdaRequest) (*types.LambdaResponse, error) {
	err := validateInput(req); if err != nil {
		return nil, fmt.Errorf("invalid input, %v", err)
	}

	// load aws config and assume customer's role
	cfg, err := config.LoadDefaultConfig(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to load configuration, %v", err)
	}

	// assumes the role is correctly setup - this verification should be done outside of this lambda
	stsClient := sts.NewFromConfig(cfg)
	assumeRoleProvider := stscreds.NewAssumeRoleProvider(stsClient, req.CustomerRoleARN)
	customerCfg := cfg.Copy()
	customerCfg.Credentials = assumeRoleProvider

	s3Client := s3.NewFromConfig(customerCfg)

	fetch := fetch.NewFetch(s3Client, "sixsevenlabs-data-dev", req.S3Keys)
	items, err := fetch.FetchS3Objects(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch items from s3, %v", err)
	}

	binPack := bin.NewBinPack(DESIRED_BIN_SIZE, ABSOLUTE_MAX_FILE_SIZE, items)
	binPackResult, err := binPack.Run()
	if err != nil {
		return nil, fmt.Errorf("failed to run bin packing algorithm, %v", err)
	}

	for i, b := range binPackResult.Bins {
		log.Printf("Bin %d: %d items, total size %d bytes\n", i, len(b), binPackResult.BinsTotal[i])
	}

	return &types.LambdaResponse{
		BinPackResult: 	*binPackResult,
		TotalBins:     	len(binPackResult.Bins),
		TotalFiles:    	len(items),
		S3Bucket:      	req.S3Bucket,
		CustomerRoleARN: req.CustomerRoleARN,
		Rules:         	req.Rules,
	}, nil
}

func main() {
	lambda.Start(HandleRequest)
}