package types

type S3Object struct {
	Key string
	Size int64
}

type BinPackResult struct {
	Bins      [][]S3Object
	BinsTotal []int64
}

type LambdaRequest struct {
	S3Bucket      	string   `json:"s3_bucket"`
	S3Keys         	[]string `json:"s3_key"`
	CustomerRoleARN string 	 `json:"customer_role_arn"`
	Rules         	[][]any  `json:"rules"`
}

type LambdaResponse struct {
    BinPackResult 	BinPackResult `json:"bin_pack_result"`
    TotalBins      	int        	  `json:"total_bins"`
    TotalFiles     	int           `json:"total_files"`
    S3Bucket       	string        `json:"s3_bucket"`
    CustomerRoleARN string        `json:"customer_role_arn"`
    Rules          	[][]any       `json:"rules"`
}