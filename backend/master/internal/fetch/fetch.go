package fetch

import "fmt"

type Fetch struct {
	Bucket     string
	ListOfKeys []string // optional
}

func NewFetch(bucket string, listOfKeys ...string) *Fetch {
	return &Fetch{
		Bucket:     bucket,
		ListOfKeys: listOfKeys,
	}
}
func fetch() {
	fmt.Println("hello")
}
