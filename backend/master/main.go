package main

import (
	"fmt"

	"github.com/sixsevenlabs/sixsevenlabs/backend/master/internal/bin"
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

const DESIRE_SIZE int64 = 128 * 1024 * 1024 // 128mb
const MAX_SIZE int64 = 256 * 1024 * 1024    // 256mb

const MAX_CONCURRENT_WORKERS int = 10 // concurrency threshold
// const LIST_SIZE int = 5000

func main() {
	fmt.Println("master")
	items := []types.S3Object{} // call fetch here
	binPack := bin.NewBinPack(DESIRE_SIZE, MAX_SIZE, items)
	bins, binsTotal := binPack.Run()
	
	for i, b := range bins {
		fmt.Printf("Bin %d: %d items, total size %d bytes\n", i, len(b), binsTotal[i])
	}

	if len(bins) > MAX_CONCURRENT_WORKERS {
		fmt.Printf("Note: %d > MaxConcurrency %d. Map State will queue extra invocations automatically.\n", len(bins), MAX_CONCURRENT_WORKERS)
	}



	// create events now

} 