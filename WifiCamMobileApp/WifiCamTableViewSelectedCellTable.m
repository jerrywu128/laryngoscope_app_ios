//
//  WifiCamTableViewSelectedCellTable.m
//  WifiCamMobileApp
//
//  Created by ZJ on 2017/3/27.
//  Copyright © 2017年 iCatchTech. All rights reserved.
//

#import "WifiCamTableViewSelectedCellTable.h"

@implementation WifiCamTableViewSelectedCellTable

-(id)initWithParameters:(NSMutableArray *)nSelectedCells
               andCount:(NSUInteger)nCount
{
    WifiCamTableViewSelectedCellTable *table = [[WifiCamTableViewSelectedCellTable alloc] init];
    table.selectedCells = nSelectedCells;
    table.count = nCount;
    return table;
}

@end
