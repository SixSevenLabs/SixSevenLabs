package fetch

import (
	"context"
	"fmt"

	"github.com/aws/aws-sdk-go-v2/service/s3"
	"github.com/sixsevenlabs/sixsevenlabs/backend/master/internal/types"
)

type Fetch struct {
	Bucket     string
	ListOfKeys []string // optional
}

// constructor
func NewFetch(bucket string, listOfKeys ...string) *Fetch {
	return &Fetch{
		Bucket:     bucket,
		ListOfKeys: listOfKeys,
	}
}

func (f *Fetch) Fetch(ctx context.Context, s3Client *s3.Client) ([]types.S3Object, error) {
	var items []types.S3Object

	// if specific keys provided, fetch only those
	if len(f.ListOfKeys) > 0 {
		for _, key := range f.ListOfKeys {
			headInput := &s3.HeadObjectInput{
				Bucket: &f.Bucket,
				Key:    &key,
			}
			output, err := s3Client.HeadObject(ctx, headInput)
			if err != nil {
				return nil, fmt.Errorf("failed to get object %s: %w", key, err)
			}
			items = append(items, types.S3Object{
				Key:  key,
				Size: *output.ContentLength,
			})
		}
		return items, nil
	}

	// otherwise, list all objects in bucket
	input := &s3.ListObjectsV2Input{
		Bucket: &f.Bucket,
	}

	paginator := s3.NewListObjectsV2Paginator(s3Client, input)
	for paginator.HasMorePages() {
		output, err := paginator.NextPage(ctx)
		if err != nil {
			return nil, fmt.Errorf("failed to list objects")
		}

		for _, obj := range output.Contents {
			items = append(items, types.S3Object{
				Key:  *obj.Key,
				Size: *obj.Size,
			})
		}
	}

	return items, nil
}
