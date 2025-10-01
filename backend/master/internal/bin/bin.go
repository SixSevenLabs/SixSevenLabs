package bin

import (
	"fmt"
	"math/rand"
)

const DESIRE_SIZE int64 = 128 * 1024 * 1024 // 128mb
const MAX_SIZE int64 = 256 * 1024 * 1024    // 256mb

const MAX_CONCURRENT_WORKERS int = 10 // concurrency threshold
const LIST_SIZE int= 5000

// main bin packing function
func RunBinPack() {
	fmt.Println("bin")
	items := makeRandomList()
	fmt.Println(items)
	items = filterLargeItems(items)
	
	bins, binsTotal := binPack(items)
	_=bins
	_=binsTotal
}


// helpers

func binPack(items []int64) (bins [][]int64, binTotals []int64) {
	maxSize := DESIRE_SIZE
	bins = [][]int64{}
	binTotals = []int64{}
	_=maxSize
	_=items
	return bins, binTotals
}

func filterLargeItems(items []int64) []int64 {
	maxSize := MAX_SIZE 
	_=maxSize
	_=items
	return nil
}

func makeRandomList() []int64 {
	minKB := 30
	maxKB := 1000
	listSize := LIST_SIZE 

	lo := minKB * 1024 
	hi := maxKB * 1024

	randomInts :=  []int64{}
	for i:=0; i<listSize; i++ {
		r:= int64(lo + rand.Intn(hi - lo + 1)) // cos go random in range is weird. gotta cast cos return value deinfition
		randomInts = append(randomInts, r) // this shit just like typescript lol 
	}

	return randomInts
}
