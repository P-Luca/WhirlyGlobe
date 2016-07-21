/*
 *  MapboxVectorStyleSymbol.h
 *  WhirlyGlobe-MaplyComponent
 *
 *  Created by Steve Gifford on 2/17/15.
 *  Copyright 2011-2015 mousebird consulting
 *
 *  Licensed under the Apache License, Version 2.0 (the "License");
 *  you may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *  http://www.apache.org/licenses/LICENSE-2.0
 *
 *  Unless required by applicable law or agreed to in writing, software
 *  distributed under the License is distributed on an "AS IS" BASIS,
 *  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *  See the License for the specific language governing permissions and
 *  limitations under the License.
 *
 */

#import "MapboxVectorStyleSymbol.h"
#import "MaplyScreenLabel.h"
#import "MaplyIconManager.h"


@implementation MapboxVectorSymbolLayout

- (instancetype)initWithStyleEntry:(NSDictionary *)styleEntry styleSet:(MaplyMapboxVectorStyleSet *)styleSet viewC:(MaplyBaseViewController *)viewC
{
    self = [super init];
    if (!self)
        return nil;
     //"symbol-placement": "line"
     //"text-transform": "uppercase",
    _placement = TextPlacementPoint;
    NSString *placement = [styleSet stringValue:@"symbol-placement" dict:styleEntry defVal:nil];
    if([placement isEqualToString:@"line"])
        _placement = TextPlacementLine;
    else if([placement isEqualToString:@"point"])
        _placement = TextPlacementPoint;
    else if([placement isEqualToString:@"interior"])
        _placement = TextPlacementInterior;
    else if([placement isEqualToString:@"vertex"])
        _placement = TextPlacementVertex;
    
    _textTransform = TextTransformNone;
    NSString *transform = [styleSet stringValue:@"text-transform" dict:styleEntry defVal:nil];
    if([transform isEqualToString:@"uppercase"])
        _textTransform = TextTransformUppercase;
    else if([transform isEqualToString:@"lowercase"])
        _textTransform = TextTransformLowercase;
    else if([transform isEqualToString:@"capitalize"])
        _textTransform = TextTransformCapitalize;
    
    _iconName = [styleSet stringValue:@"icon-image" dict:styleEntry defVal:nil];
    _textField = [styleSet stringValue:@"text-field" dict:styleEntry defVal:nil];
    if (_textField != nil) {
        _textField = [_textField substringWithRange: NSMakeRange(1, [_textField length] - 2)];
    }

    _textMaxSize = [styleSet doubleValue:@"text-max-size" dict:styleEntry defVal:128.0];
    // Note: Missing a lot of these
    
    return self;
}

@end

@implementation MapboxVectorSymbolPaint

- (instancetype)initWithStyleEntry:(NSDictionary *)styleEntry styleSet:(MaplyMapboxVectorStyleSet *)styleSet viewC:(MaplyBaseViewController *)viewC
{
    self = [super init];
    if (!self)
        return nil;
    
    _textColor = [styleSet colorValue:@"text-color" dict:styleEntry defVal:[UIColor whiteColor]];
    _textHaloColor = [styleSet colorValue:@"text-halo-color" dict:styleEntry defVal:nil];
    id sizeEntry = styleEntry[@"text-size"];
    if (sizeEntry)
    {
        if ([sizeEntry isKindOfClass:[NSNumber class]])
            _textSize = [styleSet doubleValue:sizeEntry defVal:1.0];
        else
            _textSizeFunc = [styleSet stopsValue:sizeEntry defVal:nil];
    } else
        _textSize = 24.0;

    return self;
}

@end

@implementation MapboxVectorLayerSymbol
{
    NSMutableDictionary *symbolDesc;
}

- (instancetype)initWithStyleEntry:(NSDictionary *)styleEntry parent:(MaplyMapboxVectorStyleLayer *)refLayer styleSet:(MaplyMapboxVectorStyleSet *)styleSet drawPriority:(int)drawPriority viewC:(MaplyBaseViewController *)viewC
{
    self = [super initWithStyleEntry:styleEntry parent:refLayer styleSet:styleSet drawPriority:drawPriority viewC:viewC];
    if (!self)
        return nil;
    
    _layout = [[MapboxVectorSymbolLayout alloc] initWithStyleEntry:styleEntry[@"layout"] styleSet:styleSet viewC:viewC];
    _paint = [[MapboxVectorSymbolPaint alloc] initWithStyleEntry:styleEntry[@"paint"] styleSet:styleSet viewC:viewC];

    if (!_layout)
    {
        NSLog(@"Expecting layout in symbol layer.");
        return nil;
    }
    if (!_paint)
    {
        NSLog(@"Expecting paint in symbol layer.");
        return nil;
    }
    
    // Note: Need to look up the font
    UIFont *font = [UIFont systemFontOfSize:_paint.textSize];
    
    symbolDesc = [NSMutableDictionary dictionaryWithDictionary:
                  @{kMaplyTextColor: _paint.textColor,
                    kMaplyFont: font,
                    kMaplyFade: @(0.0),
                    kMaplyEnable: @(NO)
                    }];
    if (_paint.textHaloColor)
    {
        symbolDesc[kMaplyTextOutlineColor] = _paint.textHaloColor;
        // Note: Pick this up from the spec
        symbolDesc[kMaplyTextOutlineSize] = @(2.0);
    }
    
    return self;
}

- (NSArray *)buildObjects:(NSArray *)vecObjs forTile:(MaplyTileID)tileID viewC:(MaplyBaseViewController *)viewC
{
    bool isRetina = [UIScreen mainScreen].scale > 1.0;

    NSMutableArray *compObjs = [NSMutableArray array];
    
    NSDictionary *desc = symbolDesc;
    if (_paint.textSizeFunc)
    {
        double textSize = [_paint.textSizeFunc valueForZoom:tileID.level];
        if (textSize > _layout.textMaxSize)
            textSize = _layout.textMaxSize;
        UIFont *font = [UIFont systemFontOfSize:textSize];
        NSMutableDictionary *mutDesc = [NSMutableDictionary dictionaryWithDictionary:desc];
        mutDesc[kMaplyFont] = font;
        desc = mutDesc;
    } else {
        // Note: Providing a reasonable default
        UIFont *font = [UIFont systemFontOfSize:16.0];
        NSMutableDictionary *mutDesc = [NSMutableDictionary dictionaryWithDictionary:desc];
        mutDesc[kMaplyFont] = font;
        desc = mutDesc;
    }
    
    NSMutableArray *labels = [NSMutableArray array];
    NSMutableArray *markers = [NSMutableArray array];

    for (MaplyVectorObject *vecObj in vecObjs)
    {
        MaplyScreenMarker *marker = nil;
        if (_layout.iconName != nil) {
            marker = [[MaplyScreenMarker alloc] init];
            NSString *markerName = _layout.iconName;
            marker.image =  [MaplyIconManager iconForName:markerName
                                                     size:CGSizeMake(30,30)
                                                    color:[UIColor clearColor]
                                              circleColor:[UIColor clearColor]
                                               strokeSize:2.0
                                              strokeColor:[UIColor clearColor]];
            if ([marker.image isKindOfClass:[NSNull class]])
                marker.image = nil;
            
            if (marker.image) {
                marker.loc = [vecObj center];
                marker.layoutImportance = MAXFLOAT;
                if (marker.image)
                {
                    marker.size = ((UIImage *)marker.image).size;
                    // The markers will be scaled up on a retina display, so compensate
                    if (isRetina)
                        marker.size = CGSizeMake(marker.size.width/2.0, marker.size.height/2.0);
                } else
                    marker.size = CGSizeMake(30,30);
                [markers addObject:marker];
            }
        }
        
        // Note: Cheating
        MaplyScreenLabel *label = [[MaplyScreenLabel alloc] init];
        label.loc = [vecObj center];
        NSString *nameAttribute = (_layout.textField != nil) ? _layout.textField : @"name";
        label.text = vecObj.attributes[nameAttribute];
        if(label.text == nil)
            label.text = vecObj.attributes[@"name"];
        label.layoutImportance = _layout.textMaxSize;
        if (marker != nil) {
            label.offset = CGPointMake(marker.size.width/3, marker.size.height/2*-1);
        }
        label.layoutPlacement = kMaplyLayoutCenter | kMaplyLayoutRight | kMaplyLayoutLeft | kMaplyLayoutAbove | kMaplyLayoutBelow;
        if (label.text)
        {
            switch (_layout.textTransform)
            {
                case TextTransformCapitalize:
                    label.text = [label.text capitalizedString];
                    break;
                case TextTransformLowercase:
                    label.text = [label.text lowercaseString];
                    break;
                case TextTransformUppercase:
                    label.text = [label.text uppercaseString];
                    break;
                default:
                    break;
            }
            
            if(_layout.placement == TextPlacementPoint ||
               _layout.placement == TextPlacementInterior)
            {
                MaplyCoordinate center = [vecObj center];
                label.loc = center;
            } else if (_layout.placement == TextPlacementLine)
            {
                MaplyCoordinate middle;
                double rot;
                if ([vecObj linearMiddle:&middle rot:&rot displayCoordSys:viewC.coordSystem])
                {
                    //TODO: text-max-char-angle-delta
                    //TODO: rotation calculation is not ideal, it is between 2 points, but it needs to be avergared over a longer distance
                    label.loc = middle;
                    label.layoutPlacement = kMaplyLayoutCenter;
                    label.rotation = -1 * rot+M_PI/2.0;
                    if(label.rotation > M_PI_2 || label.rotation < -M_PI_2) {
                        label.rotation += M_PI;
                    }
                    
                    label.keepUpright = true;
                } else {
                    label = nil;
                }
            } else if(_layout.placement == TextPlacementVertex)
            {
                MaplyCoordinate vertex;
                if([vecObj middleCoordinate:&vertex]) {
                    label.loc = vertex;
                } else {
                    label = nil;
                }
            }
            if (label)
                [labels addObject:label];
        }
        // Note: Tossing labels without text
    }
    
    MaplyComponentObject *compObj = [viewC addScreenLabels:labels desc:desc mode:MaplyThreadCurrent];
    if (compObjs)
        [compObjs addObject:compObj];

    MaplyComponentObject *markerObj = [viewC addScreenMarkers:markers desc:desc mode:MaplyThreadCurrent];
    if (markerObj)
        [compObjs addObject:markerObj];
    
    return compObjs;
}

@end
