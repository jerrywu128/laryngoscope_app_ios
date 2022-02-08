//
//  WifiCamTableViewSelectedCellTable.h
//  WifiCamMobileApp
//
//  Created by ZJ on 2017/3/27.
//  Copyright © 2017年 iCatchTech. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface WifiCamTableViewSelectedCellTable : NSObject

@property(nonatomic) NSMutableArray *selectedCells;
@property(nonatomic) NSUInteger count;

-(id)initWithParameters:(NSMutableArray *)nSelectedCells
               andCount:(NSUInteger)nCount;

@end
