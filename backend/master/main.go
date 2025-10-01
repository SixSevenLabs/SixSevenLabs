package main

import (
	"fmt"
	"github.com/sixsevenlabs/sixsevenlabs/backend/master/internal/bin"
)

// master lambda function: implements bin packing algorithm for splitting up data into chunks

// domain (assumes a valid "job" requested and does not care about status of job after):
// - fetching object keys from s3
// - checking job status (to check if new job or already runinng but this depends on how we want to handle data)
// - splitting up data into chunks
// - calling augmentor lambda

func main() {
	fmt.Println("master")
	bin.RunBinPack()
}