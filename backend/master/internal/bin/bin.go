package bin

import (
	"fmt"

	"github.com/sixsevenlabs/sixsevenlabs/backend/master/internal/types"
)

type BinPack struct {
	DesiredSize       int64
	MaxSize           int64
	ConcurrentWorkers int
	ListSize          int
	Items             []types.S3Object
}

// constructor
func NewBinPack(desiredSize int64, maxSize int64, items []types.S3Object) *BinPack {
	return &BinPack{
		DesiredSize: desiredSize,
		MaxSize:     maxSize,
		Items:       items,
	}
}

// run function
func (b *BinPack) Run() ([][]types.S3Object, []int64) {
	fmt.Println("bin")
	fmt.Println(b.Items)
	filteredItems := b.filterLargeItems() // this copies but apparently good practice
	bins, binsTotal := b.binPack(filteredItems)
	return bins, binsTotal
}

// main bin pack algorithm
func (b *BinPack) binPack(items []types.S3Object) (bins [][]types.S3Object, binTotals []int64) {
	maxSize := b.DesiredSize
	bins = [][]types.S3Object{}
	binTotals = []int64{}

	for _, item := range items {
		inserted := false
		for i, binSize := range binTotals {
			if binSize+item.Size <= maxSize {
				bins[i] = append(bins[i], item) // why is it like this smhhh
				binTotals[i] += item.Size
				inserted = true
				break
			}
		}
		if !inserted { // create new bin if not desired size
			bins = append(bins, []types.S3Object{item})
			binTotals = append(binTotals, item.Size)
		}

	}

	return bins, binTotals
}

func (b *BinPack) filterLargeItems() []types.S3Object {
	maxSize := int64(float64(b.MaxSize) * 1.2)

	filteredItems := []types.S3Object{}

	for _, item := range b.Items {
		if item.Size <= maxSize {
			filteredItems = append(filteredItems, item)
		} else {
			fmt.Printf("Warning: item of size %d bytes exceeds max allowed size of %d bytes and will be skipped.\n", item.Size, maxSize)
		}
	}

	// just calculating total size to print
	totalSize := int64(0)
	for _, item := range filteredItems {
		totalSize += item.Size
	}
	fmt.Println(fmt.Sprintf("After filtering, %d items with total size %d bytes", len(filteredItems), totalSize))
	return filteredItems
}
