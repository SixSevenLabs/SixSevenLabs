package bin

import (
	"fmt"

	"github.com/sixsevenlabs/sixsevenlabs/backend/master/internal/types"
)

type BinPack struct {
	DesiredBinSize       int64
	AbsoluteMaxFileSize  int64
	ConcurrentWorkers    int
	ListSize             int
	Items                []types.S3Object
}

// constructor
func NewBinPack(desiredSize int64, maxSize int64, items []types.S3Object) *BinPack {
	return &BinPack{
		DesiredBinSize: desiredSize,
		AbsoluteMaxFileSize: maxSize,
		Items:       items,
	}
}

// run function
func (b *BinPack) Run() ([][]types.S3Object, []int64, error) {
	fmt.Println("bin")
	fmt.Println(b.Items)
	
	filteredItems, err := b.filterLargeItems()
	if err != nil {
		return nil, nil, err
	}

	bins, binsTotal := b.binPack(filteredItems)
	return bins, binsTotal, nil
}

// main bin pack algorithm
func (b *BinPack) binPack(items []types.S3Object) ([][]types.S3Object,	 []int64) {
	var bins [][]types.S3Object
	var binTotals []int64

	for _, item := range items {
		inserted := false
		for i, binSize := range binTotals {
			if binSize+item.Size <= b.DesiredBinSize {
				bins[i] = append(bins[i], item)
				binTotals[i] += item.Size
				inserted = true
				break
			}
		}
		if !inserted {
			// create new bin if... (1) no bins exist (2) item doesn't fit into existing bin (3) DesiredBinSize <= item <= AbsoluteMaxFileSize 
			bins = append(bins, []types.S3Object{item})
			binTotals = append(binTotals, item.Size)
		}

	}

	return bins, binTotals
}

func (b *BinPack) filterLargeItems() ([]types.S3Object, error) {
	var filteredItems []types.S3Object

	for _, item := range b.Items {
		if item.Size <= b.AbsoluteMaxFileSize {
			filteredItems = append(filteredItems, item)
		} else {
			fmt.Printf("Warning: item of size %d bytes exceeds max allowed size of %d bytes and will be skipped.\n", item.Size, b.AbsoluteMaxFileSize)
		}
	}

	if len(filteredItems) == 0 {
		return nil, fmt.Errorf("no items to process after filtering")
	}

	// just calculating total size to print
	totalSize := int64(0)
	for _, item := range filteredItems {
		totalSize += item.Size
	}

	fmt.Println(fmt.Sprintf("After filtering, %d items with total size %d bytes", len(filteredItems), totalSize))

	return filteredItems, nil
}
