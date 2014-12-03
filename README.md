# AccelerateExample

Sample usage of the Accelerate framework

## Usage

Uncomment the various method calls to compare CPU time necessary to compute matrix multiplication in a naive implementation vs an accelerated implementation.

## Results

### Naive

Note the spike.

![Naive implementation](data/naive graph.png)

### Accelerated

Note the downward trend once we reach a larger dataset. Total size of matrices is approximately 105,000,000 in last data point.

![Accelerated implementation](data/accelerated graph.png)

## Notes

Results for matrix multiplication obtained from running on a Late 2011 MacBook Pro 13” i7 with 16GB memory

![My Mac](data/mac stats.png)
