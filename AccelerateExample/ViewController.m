//
//  ViewController.m
//  Math
//
//  Created by Sean Soper on 11/29/14.
//  Copyright (c) 2014 The Washington Post. All rights reserved.
//

#import <mach/mach_time.h>
#import <Accelerate/Accelerate.h>

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

mach_timebase_info_data_t static TimeInfo;
BOOL static TimeInfoSucceeded;

- (void)viewDidLoad {
    [super viewDidLoad];

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if(mach_timebase_info(&TimeInfo) == KERN_SUCCESS)
            TimeInfoSucceeded = YES;
    });

    // Step 1
    [self simpleMatrix];

    // Step 2
    // [self complexMatrix: 5 n: 7 p: 10 naive: YES];
    // [self complexMatrix: 50 n: 70 p: 10 naive: YES];
    // [self complexMatrix: 500 n: 700 p: 10 naive: YES];
    // [self complexMatrix: 5000 n: 7000 p: 10 naive: YES];

    /*
     * These functions take a long time to complete
     */
    // [self complexMatrix: 5000 n: 7000 p: 100 naive: YES]; // Takes 88 seconds
    // [self complexMatrix: 5000 n: 7000 p: 1000 naive: YES]; // Still wasn't finished after 90 minutes

    // Step 3
    // [self simpleAcceleratedMatrix];

    // Step 4
    // [self complexMatrix: 5 n: 7 p: 10 naive: NO];
    // [self complexMatrix: 50 n: 70 p: 10 naive: NO];
    // [self complexMatrix: 500 n: 700 p: 10 naive: NO];
    // [self complexMatrix: 5000 n: 7000 p: 10 naive: NO];
    // [self complexMatrix: 5000 n: 7000 p: 100 naive: NO];
    // [self complexMatrix: 5000 n: 7000 p: 1000 naive: NO];
    // [self complexMatrix: 5000 n: 7000 p: 10000 naive: NO];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Simple

- (void) simpleMatrix {
    // Simple vector multiplication sample
    //
    // |1 2 3|   |7   8|   |58   64|
    // |4 5 6| x |9  10| = |139 154|
    //           |11 12|

    NSArray *arrayA = @[@[@1,@2,@3], @[@4,@5,@6]];
    NSArray *arrayB = @[@[@7,@8], @[@9,@10], @[@11,@12]];

    [self naiveMatrixMultiplication: arrayA matrixB: arrayB showResult: YES logTitle: @"Simple matrix"];
}

- (void) simpleAcceleratedMatrix {
    float a[6] = {1, 2, 3, 4, 5, 6};
    float b[6] = {7, 8, 9, 10, 11, 12};
    float result[4];

    vDSP_mmul(a, 1, b, 1, result, 1, 2, 2, 3);
}

#pragma mark - Complex

- (void) complexMatrix:(NSUInteger) m   // rows in matrix A
                     n:(NSUInteger) n   // cols in matrix B
                     p:(NSUInteger) p   // cols in matrix A and rows in matrix B
                 naive:(BOOL) naive {

    uint64_t startTime = mach_absolute_time();

    dispatch_group_t group = dispatch_group_create();

    __block NSArray *arrayA;
    dispatch_group_enter(group);
    [self buildMatrix: m innerCount: p completionBlock:^(NSArray *matrix) {
        arrayA = [NSArray arrayWithArray: matrix];
        dispatch_group_leave(group);
    }];

    __block NSArray *arrayB;
    dispatch_group_enter(group);
    [self buildMatrix: p innerCount: n completionBlock:^(NSArray *matrix) {
        arrayB = [NSArray arrayWithArray: matrix];
        dispatch_group_leave(group);
    }];

    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
    NSString *title = [NSString stringWithFormat: @"Complex matrices of %ldx%ld and %ldx%ld", m, n, n, p];

    uint64_t endTime = mach_absolute_time();

    if(TimeInfoSucceeded) {
        uint64_t nanos = ((endTime - startTime) * TimeInfo.numer) / TimeInfo.denom;
        CGFloat timeTook = (CGFloat)nanos / NSEC_PER_MSEC;
        NSLog(@"Done building %@ took %f seconds", [title substringFromIndex: 8], timeTook);
    }

    if (naive)
        return [self naiveMatrixMultiplication: arrayA matrixB: arrayB showResult: NO logTitle: title];

    [self acceleratedMatrixMultiplication: arrayA arrayB: arrayB m: m n: n p: p showResult: NO logTitle: title];
}

#pragma mark - Matrix multipliers

/**
 * A 2x2 matrix is represented as such:
 *
 * |1 2| == [[1,2],[5,7]]
 * |5 7|
 *
 * When multiplying matrices of different sizes ensure that n matches such that: mxn * nxp
 */

- (void) naiveMatrixMultiplication:(NSArray *) matrixA
                           matrixB:(NSArray *) matrixB
                        showResult:(BOOL) showResult
                          logTitle:(NSString *) logTitle {

    uint64_t startTime = mach_absolute_time();

    NSMutableArray *matrix = [NSMutableArray new];

    for (int i=0; i<matrixA.count; i++) {
        NSArray *arrayA = matrixA[i];

        for (int n=0; n<matrixA.count; n++) {

            for (int j=0; j<arrayA.count; j++) {
                NSArray *arrayB = matrixB[j];

                NSNumber *result = [NSNumber numberWithInteger: [arrayA[j] integerValue] * [arrayB[n] integerValue]];

                if (i == matrix.count) {
                    [matrix addObject: [NSMutableArray array]];
                }

                NSMutableArray *aryA = matrix[i];

                // Uncomment for debugging but be aware that it can seriously slow down computations
                //  NSLog(@"i%u, j%u, n%u, %ld x %ld = %ld", i, j, n, [arrayA[j] integerValue], [arrayB[n] integerValue], result.integerValue);

                if (n < aryA.count) {
                    NSNumber *curr = aryA[n];
                    curr = [NSNumber numberWithInteger: curr.integerValue + result.integerValue];
                    [aryA setObject: curr atIndexedSubscript: n];
                } else {
                    [aryA insertObject: result atIndex: n];
                }

            }
        }
    }

    uint64_t endTime = mach_absolute_time();

    if(TimeInfoSucceeded) {
        uint64_t nanos = ((endTime - startTime) * TimeInfo.numer) / TimeInfo.denom;
        CGFloat timeTook = (CGFloat)nanos / NSEC_PER_MSEC;
        NSLog(@"%@ took %f seconds", logTitle, timeTook);
    }

    if (!showResult)
        return;

    for (int i=0; i<matrix.count; i++) {
        NSArray *arrayA = matrix[i];
        NSLog(@"| %@ |", [arrayA componentsJoinedByString: @", "]);
    }
}

- (void) acceleratedMatrixMultiplication:(NSArray *) arrayA
                                  arrayB:(NSArray *) arrayB
                                       m:(NSUInteger) m
                                       n:(NSUInteger) n
                                       p:(NSUInteger) p
                              showResult:(BOOL) showResult
                                logTitle:(NSString *) logTitle {

    NSArray *flatA = [self flattened: arrayA];
    float *matrixA = (float *)malloc(flatA.count * sizeof(float));
    for (int i=0; i<flatA.count; i++) {
        matrixA[i] = (float)[flatA[i] floatValue];
    }

    NSArray *flatB = [self flattened: arrayB];
    float *matrixB = (float *)malloc(flatB.count * sizeof(float));
    for (int i=0; i<flatB.count; i++) {
        matrixB[i] = [flatB[i] floatValue];
    }

    float *result = (float *)malloc(m*n*sizeof(float));

    uint64_t startTime = mach_absolute_time();

    vDSP_mmul(matrixA, 1, matrixB, 1, result, 1, m, n, p);

    uint64_t endTime = mach_absolute_time();

    if(TimeInfoSucceeded) {
        uint64_t nanos = ((endTime - startTime) * TimeInfo.numer) / TimeInfo.denom;
        CGFloat timeTook = (CGFloat)nanos / NSEC_PER_MSEC;
        NSLog(@"%@ took %f seconds", logTitle, timeTook);
    }

    if (!showResult)
        return;

    for (int i=0; i<m*n; i++) {
        NSLog(@"Value %f", result[i]);
    }
}

#pragma mark - Helpers

- (void) buildMatrix:(NSUInteger) outerCount
          innerCount:(NSUInteger) innerCount
     completionBlock:(void (^)(NSArray *matrix)) completionBlock {

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSMutableArray *matrix = [NSMutableArray array];
        @autoreleasepool {
            for (int i=0; i < outerCount; i++) {
                NSMutableArray *inner = [NSMutableArray array];
                for (int j=0; j < innerCount; j++) {
                    [inner addObject: @(arc4random_uniform(10000)+1)];
                }

                [matrix addObject: [[NSArray alloc] initWithArray: inner]];
            }
        }

        completionBlock([NSArray arrayWithArray: matrix]);
    });
}

- (NSArray *) flattened:(NSArray *) array {
    return [array valueForKeyPath: @"@unionOfArrays.self"];
}

@end
