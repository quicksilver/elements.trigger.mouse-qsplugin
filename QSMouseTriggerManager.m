//
//  QSMouseTriggerManager.m
//  Quicksilver
//
//  Created by Nicholas Jitkoff on Sun Jun 13 2004.
//  Copyright (c) 2004 __MyCompanyName__. All rights reserved.
//

#import "QSMouseTriggerManager.h"
#import "QSMouseTriggerView.h"

#import <Carbon/Carbon.h>
#define QSTriggerCenter NSClassFromString(@"QSTriggerCenter")
#define NSAllModifierKeysMask (NSShiftKeyMask|NSControlKeyMask|NSAlternateKeyMask|NSCommandKeyMask|NSFunctionKeyMask)

@implementation NSEvent (CarbonConversion)
- (NSEvent *)mouseEventWithCarbonClickEvent:(EventRef)theEvent{
	return nil;
}
@end
@interface QSMouseTriggerTableCell : NSTextFieldCell
@end
@implementation QSMouseTriggerTableCell
- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView{
	
	NSRect imageRect,textRect;
	NSDivideRect(cellFrame,&imageRect,&textRect,NSHeight(cellFrame),NSMinXEdge);
	
	[[NSColor lightGrayColor]set];
	//NSRectFill(imageRect);	
	[NSGraphicsContext currentContext];
	
	
	NSAffineTransform *flipTransform=[NSAffineTransform transform];
	[flipTransform translateXBy:0 yBy:NSMinY(cellFrame)];
	[flipTransform scaleXBy:1 yBy:-1];
	[flipTransform translateXBy:0 yBy:-NSMaxY(cellFrame)];
	
	[flipTransform concat];
	
	NSUInteger anchors=[[[self representedObject] objectForKey:@"anchorMask"] unsignedIntegerValue];
	
	
	NSBezierPath *path=[NSBezierPath bezierPath];
	[path appendBezierPathWithRoundedRectangle:NSInsetRect(imageRect,4,4)
									withRadius:2];
	[path fill];
	
	[[NSColor blueColor]set];
	imageRect=NSInsetRect(imageRect,1,1);
	if (anchors&QSMinXAnchorMask) //Left
		NSRectFill(rectForAnchor(QSMinXAnchor, imageRect,2,4));
	
	if (anchors&QSTopLeftAnchorMask)
		NSRectFill(rectForAnchor(QSTopLeftAnchor, imageRect,2,4));
	
	if (anchors&QSMaxYAnchorMask) //Top
		NSRectFill(rectForAnchor(QSMaxYAnchor, imageRect,2,4));
	
	if (anchors&QSTopRightAnchorMask)
		NSRectFill(rectForAnchor(QSTopRightAnchor, imageRect,2,4));
	
	if (anchors&QSMaxXAnchorMask) //Right
		NSRectFill(rectForAnchor(QSMaxXAnchor, imageRect,2,4));
	
	if (anchors&QSBottomRightAnchorMask)
		NSRectFill(rectForAnchor(QSBottomRightAnchor, imageRect,2,4));
	
	if (anchors&QSMinYAnchorMask) //Bottom
		NSRectFill(rectForAnchor(QSMinYAnchor, imageRect,2,4));
	
	if (anchors&QSBottomLeftAnchorMask)
		NSRectFill(rectForAnchor(QSBottomLeftAnchor, imageRect,2,4));
	
	
	
	[flipTransform invert];
	[flipTransform concat];
	
	[super drawWithFrame:textRect inView:controlView];	
}
@end


OSStatus mouseActivated(EventHandlerCallRef nextHandler, EventRef theEvent, void *userData) {
	EventMouseButton button;
    GetEventParameter(theEvent, kEventParamMouseButton,typeMouseButton,0,
					  sizeof(button),0,&button);
	
	//	NSLog(@"------------------event %d",button);
	return CallNextEventHandler(nextHandler, theEvent); 
	return eventNotHandledErr;
}
BOOL is1043;
@implementation QSMouseTriggerManager
+(void)registerEventHandlers{
	//	if (VERBOSE) NSLog(@"Registering for Global Mouse Events");
	static EventHandlerRef trackMouse;
	EventTypeSpec eventType[2]={{kEventClassMouse, kEventMouseUp}, {kEventClassMouse, kEventMouseDown}};
	EventHandlerUPP handlerFunction = NewEventHandlerUPP(mouseActivated);
	InstallEventHandler(GetEventMonitorTarget(), handlerFunction, 2, eventType, NULL, &trackMouse);
}
+ (void)initialize{	
	SInt32 version;
	Gestalt (gestaltSystemVersion, &version);
	if (version >= 0x1043){
		is1043=YES;
		[self registerEventHandlers];
	}
	
}
- (NSCell *)descriptionCellForTrigger:(QSTrigger *)trigger{
	return	[[[QSMouseTriggerTableCell alloc]init]autorelease];
}

-(NSString *)name{
	return @"Mouse";
}
-(NSImage *)image{
	return [NSImage imageNamed:@"MouseTrigger"];
}
- (void)initializeTrigger:(NSMutableDictionary *)trigger{
	if (![trigger objectForKey:@"eventType"])
		[trigger setObject:[NSNumber numberWithUnsignedInteger:NSLeftMouseDown] forKey:@"eventType"];	
}

+ (id)sharedInstance{
    static QSMouseTriggerManager *_sharedInstance = nil;
    if (!_sharedInstance){
        _sharedInstance = [[[self class] allocWithZone:[self zone]] init];
    }
    return _sharedInstance;
}

- (id) init{
    if (self=[super init]){
        anchorWindows=[[NSMutableDictionary alloc]initWithCapacity:0];
        anchorArrays=[[NSMutableDictionary alloc]initWithCapacity:0];
        anywhereArray=[[NSMutableArray alloc]init];
		// int i;
		//  for (i=1;i<9;i++)
		//   [anchorArrays setObject:[NSMutableArray arrayWithCapacity:0] forKey:[NSString stringWithFormat:@"%d",i]];
		
		//NSLog(@"init");
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationDidChangeScreenParameters:)
                                                     name:NSApplicationDidChangeScreenParametersNotification object:nil];
		
		[self addObserver:self
			   forKeyPath:@"currentTrigger"
				  options:0
				  context:nil];
    }
    return self;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context{
	[self populateInfoFields];
}


-(NSMutableArray *)anchorArrayForScreen:(NSInteger)screen anchor:(NSUInteger)anchor{
	NSString *key=[NSString stringWithFormat:@"%ld:%lu",(long)screen, (unsigned long)anchor];
	NSMutableArray *array=[anchorArrays objectForKey:key];
	if (!array){
		array=[NSMutableArray array];
		[anchorArrays setObject:array forKey:key];
		//NSLog(@"Set %@",key);
	}
	return array;
}

-(void)addTriggerDictionary:(NSDictionary *)entry toAnchorArray:(NSUInteger)anchor forScreens:(NSArray *)screens {
    for (NSScreen *screen in screens) {
        NSMutableArray *matchedArray = 	[self anchorArrayForScreen:[screen screenNumber] anchor:anchor];
        if (![matchedArray containsObject:entry]) {
            [matchedArray addObject:entry];
        }
    }
}

// Gets the screen(s) (as an array) based on the tag of the popup menu in the trigger settings
-(NSArray *)screensForScreenTag:(NSInteger)screenTag {
    
    NSArray *screens=[NSScreen screens];
	NSUInteger screenCount=[screens count];

    if (screenTag==0 || (screenTag==-1 && screenCount==1)) {
        return [NSArray arrayWithObject:[screens objectAtIndex:0]];
    } else if (screenTag==1) {
        if (screenCount>1) {
            return [NSArray arrayWithObject:[screens objectAtIndex:1]];
        }
    } else if (screenTag==-1 && screenCount>1) {
        return screens;
    } else {
        return [NSArray arrayWithObject:[NSScreen screenWithNumber:screenTag]];
    }
    
    return nil;
    
}

-(BOOL)enableTrigger:(NSDictionary *)entry{
	NSUInteger anchorMask=[[entry objectForKey:@"anchorMask"] unsignedIntegerValue];
	BOOL anywhere=[[entry objectForKey:@"anywhere"]boolValue];
    NSInteger screenTag = [[entry objectForKey:@"screen"] integerValue];

	if (anywhere)
		[anywhereArray addObject:entry];
	
	NSUInteger i;
	//NSArray *array;
	for (i=1;i<9;i++){
		if ((1 << i) & anchorMask){
            [self addTriggerDictionary:entry toAnchorArray:i forScreens:[self screensForScreenTag:screenTag]];
		}
		
	}
	[self updateTriggerWindows];
	
    return YES;
}

-(BOOL)disableTrigger:(NSDictionary *)entry{
	//   NSString *theID=[entry objectForKey:kItemID];
    [[anchorArrays allValues]makeObjectsPerformSelector:@selector(removeObject:) withObject:entry];
	[anywhereArray removeObject:entry];
	[self updateTriggerWindows];
    return YES;
}

- (NSWindow *)triggerDescriptionWindowForAnchor:(NSUInteger)anchor onScreen:(NSScreen *)screen{
	//	NSArray *array=[anchorArrays objectForKey:[NSString stringWithFormat:@"%d",anchor]];
	
	
	//	NSDictionary *[currentTrigger info];
	//	NSEnumerator *triggerEnum=[[anchorArrays objectForKey:[NSString stringWithFormat:@"%d",anchor]]objectEnumerator];
    
	//    while([currentTrigger info]=[triggerEnum nextObject]){
	//		NSLog(@"\rTrigger: %@\rCommand: %@",[self descriptionForTrigger:[currentTrigger info]],[[QSTriggerCenter commandForTrigger:[currentTrigger info]]description]);
	//	}	
	return nil;
}



- (void)handleMouseTriggerEvent:(NSEvent *)theEvent type:(NSEventType)type forView:(QSMouseTriggerView *)view{
	//NSLog(@"Mouse %@",theEvent);
	NSUInteger anchor= view ? view->anchor : -1;
	NSInteger screen= view ? view->screenNum : -1;
	NSArray *enumerateArray=nil;
	
	if (!view)
		enumerateArray = anywhereArray;
    else
		enumerateArray = [anchorArrays objectForKey:[NSString stringWithFormat:@"%ld:%lu",screen,anchor]];
    
	NSMutableArray *matchedTriggers=[NSMutableArray array];
	BOOL checkForMoreClicks=NO;
	//BOOL checkForDelay=NO;
	
	//int inverseEvent=0;
	NSEventType inverseEventMask = 1 << (type+1);
	NSDate *date=[NSDate date];
	CGFloat thisDelay = 0.0;
	CGFloat longestDelay = 0.0;
    for (QSTrigger *thisTrigger in enumerateArray){
		if (!type) {
            type = [theEvent type];
        }
        if ([[[thisTrigger info] objectForKey:@"eventType"] unsignedIntegerValue]!=type) {
            continue;
        }
        if (!theEvent) {
            theEvent = [NSApp currentEvent];
        }
		if (type==NSOtherMouseDown && [[[thisTrigger info] objectForKey:@"buttonNumber"] integerValue]!=([theEvent buttonNumber]+1)) {
            continue;
        }
        
		NSUInteger flags=[[[thisTrigger info] objectForKey:@"modifierFlags"] unsignedIntegerValue];
		
		NSUInteger currentFlags=[theEvent modifierFlags];
		
		if(flags!=(currentFlags&NSAllModifierKeysMask)) {
            continue;
        }
		
		if (type==NSLeftMouseDown || type==NSRightMouseDown || type==NSOtherMouseDown){
#warning if only single click events are enabled, multi clicks should still resolve
			NSInteger clickCount=[[[thisTrigger info] objectForKey:@"clickCount"] unsignedIntegerValue];
			if (!clickCount) {
                clickCount=1;
            }
			if (clickCount != [theEvent clickCount]) {
				if (clickCount>[theEvent clickCount])
					checkForMoreClicks=YES;
				continue;
			}
		}
		
		id delayValue=[[thisTrigger info] objectForKey:@"delay"];
		thisDelay = delayValue ? [delayValue doubleValue]:0;
		
		if (thisDelay<longestDelay) {
			continue;
		} else if (thisDelay>longestDelay) {
			//NSLog(@"lookingForDelay %f",thisDelay,longestDelay);
			NSEvent *anEvent=[NSApp nextEventMatchingMask:inverseEventMask untilDate:[date dateByAddingTimeInterval:thisDelay] inMode:NSDefaultRunLoopMode dequeue:NO];
			
			if (anEvent){				
				continue;
			}else {
				
				//NSLog(@"accepting x, clearing previous %d",[matchedTriggers count]);
				longestDelay = thisDelay;
				[matchedTriggers removeAllObjects];
			}
			
		}
		
		[matchedTriggers addObject:thisTrigger];
		
	}
	
	
	if (checkForMoreClicks){
		NSEvent *anotherClick=[NSApp nextEventMatchingMask:1<<[theEvent type] untilDate:[NSDate dateWithTimeIntervalSinceNow:0.2] inMode:NSDefaultRunLoopMode dequeue:NO];
		if (anotherClick) return;
	}
	
	for(id match in matchedTriggers){
		[[QSTriggerCenter sharedInstance] executeTrigger:match]; 
	}
	
}

- (void)handleMouseTriggerEvent:(NSEvent *)theEvent forView:(QSMouseTriggerView *)view{
	[self handleMouseTriggerEvent:theEvent type:[theEvent type] forView:view];
}

//- (NSString *)descriptionForTrigger:(NSDictionary *)dict{return [[self class]descriptionForTrigger:dict];}
- (NSString *)descriptionForTrigger:(NSDictionary *)dict{
	
	//return [self descriptionForMouseTrigger:dict];
	NSUInteger anchors=[[dict objectForKey:@"anchorMask"] unsignedIntegerValue];
	
	NSMutableString *desc=[NSMutableString stringWithCapacity:0];
    
	NSMutableArray *anchorArray=[NSMutableArray array];
	
	if (anchors&QSMinXAnchorMask) //Left
		[anchorArray addObject:[NSString stringWithFormat:@"%C",0x2190]];
	
	if (anchors&QSTopLeftAnchorMask)
		[anchorArray addObject:[NSString stringWithFormat:@"%C",0x2196]];
	
	if (anchors&QSMaxYAnchorMask) //Top
		[anchorArray addObject:[NSString stringWithFormat:@"%C",0x2191]];
	
	if (anchors&QSTopRightAnchorMask)
		[anchorArray addObject:[NSString stringWithFormat:@"%C",0x2197]];
	
	if (anchors&QSMaxXAnchorMask) //Right
		[anchorArray addObject:[NSString stringWithFormat:@"%C",0x2192]];
	
	if (anchors&QSBottomRightAnchorMask)
		[anchorArray addObject:[NSString stringWithFormat:@"%C",0x2198]];
	
	if (anchors&QSMinYAnchorMask) //Bottom
		[anchorArray addObject:[NSString stringWithFormat:@"%C",0x2193]];
	
	if (anchors&QSBottomLeftAnchorMask)
		[anchorArray addObject:[NSString stringWithFormat:@"%C",0x2199]];
				
	[desc appendString:[self descriptionForMouseTrigger:dict]];
	
	if ([anchorArray count])
		[desc appendFormat:@"(%@)",[anchorArray componentsJoinedByString:@","]];
				
				
	return desc;
}


- (NSString *)descriptionForMouseTrigger:(NSDictionary *)dict{
	
    NSMutableString *desc=[NSMutableString stringWithCapacity:0];
    
    NSUInteger modifiers=[[dict objectForKey:@"modifierFlags"] unsignedIntegerValue];
	
	
    
    if (modifiers&NSShiftKeyMask)[desc appendFormat:@"%C",0x21e7];
    if (modifiers&NSControlKeyMask)[desc appendFormat:@"%C",0x2303];
    if (modifiers&NSAlternateKeyMask)[desc appendFormat:@"%C",0x2325];
    if (modifiers&NSCommandKeyMask)[desc appendFormat:@"%C",0x2318];
    if (modifiers&NSFunctionKeyMask)[desc appendString:@"Fn"];
    
    NSEventType type=[[dict objectForKey:@"eventType"] unsignedIntegerValue];
	
	
    switch (type){
        case NSLeftMouseDown:
            [desc appendFormat:@"%C",0x25BD];
            break;
        case NSRightMouseDown:
            [desc appendFormat:@"%C%C",0x25BD,0x1D3F];
            break;
        case NSOtherMouseDown:
			switch ([[dict objectForKey:@"buttonNumber"] integerValue]){
				case 3: [desc appendFormat:@"%C%C",0x25BD,0x00B3]; break;
				case 4: [desc appendFormat:@"%C%C",0x25BD,0x2074]; break;
				case 5: [desc appendFormat:@"%C%C",0x25BD,0x2075]; break;
				default:  [desc appendFormat:@"%C?",0x25BD]; break;
			}
            break;
        case 101:
            [desc appendFormat:@"Drag Enter"];
            break;
        case 102:
            [desc appendFormat:@"Drag Exit"];
            break;
        case NSMouseEntered:
            [desc appendFormat:@"Mouse Enter"];
            break;
		case NSMouseExited:
            [desc appendFormat:@"Mouse Exit"];
            break;
        default:
            break;
    }
    
    
    NSInteger clickCount=[[dict objectForKey:@"clickCount"] integerValue];
    if (clickCount>1)
        [desc appendFormat:@"%C%d",0x00D7,clickCount];
    
    
	//   NSLog(@"clickdel %@",[dict objectForKey:@"clickDelay"]);
    if ([dict objectForKey:@"delay"] && [[dict objectForKey:@"delay"]doubleValue]>0)
        [desc appendFormat:@"...%.1fs",[[dict objectForKey:@"clickDelay"]doubleValue]];
    
    
    
    return desc;
}

- (void)updateTriggerWindows{
    
    NSEnumerator *keyEnum=[anchorArrays keyEnumerator];
    NSString *key;
    
    NSEnumerator *triggerEnum;
    BOOL visible;
    BOOL clickable;
    BOOL draggable;
	NSInteger mainScreenNum=[[NSScreen mainScreen]screenNumber];
	//  NSLog(@"asch%@",anchorArrays);
    while (key=[keyEnum nextObject]){
        triggerEnum=[[anchorArrays objectForKey:key]objectEnumerator];
        visible=clickable=draggable=NO;
        NSMutableArray *tips=[NSMutableArray arrayWithCapacity:0];
        for(QSTrigger *thisTrigger in triggerEnum){
            
            if (![[[thisTrigger info] objectForKey:@"enabled"] boolValue]) {
                continue;
            }
            
            [tips addObject:[NSString stringWithFormat:@"%@:\t%@",[self descriptionForMouseTrigger:[thisTrigger info]],[thisTrigger name]]];
            visible=YES;
            NSEventType type=[[[thisTrigger info] objectForKey:@"eventType"] unsignedIntegerValue];
            switch (type){
                case NSLeftMouseDown:
                case NSRightMouseDown:
                case NSOtherMouseDown:
                    clickable=YES;
                    break;
                case 100:
                case 101:
				case 102:
                    draggable=YES;
                    break;
                case NSMouseEntered:
                    break;
                default:
                    break;
            }
        }
        
        if (visible){
            NSWindow *window=[anchorWindows objectForKey:key];
            if (!window){
				NSArray *components=[key componentsSeparatedByString:@":"];
				NSInteger tempAnchor;
                [[NSScanner scannerWithString:[components objectAtIndex:1]] scanInteger:&tempAnchor] ;
                NSUInteger anchor = (NSUInteger)tempAnchor;
				NSInteger screenNum;
                [[NSScanner scannerWithString:[components objectAtIndex:0]] scanInteger:&screenNum];
				
				//	NSLog(@"%d %x",anchor,screenNum);
				if (anchor==QSMaxYAnchor && screenNum==mainScreenNum){
					//	NSLog(@"skipping menu edge");
				}else{
					
					window=[QSMouseTriggerView triggerWindowWithAnchor:anchor
														   onScreenNum:screenNum];
					[anchorWindows setObject:window forKey:key];
					//NSLog(@"Creating anchor window %@",key);
					[[window contentView]setToolTip:nil];
				}
            }
            [[window contentView] setToolTip:[tips componentsJoinedByString:@"\r"]];
            [window orderFront:self];
            [window setIgnoresMouseEvents:!(clickable || draggable)];
        }else{
            [anchorWindows removeObjectForKey:key];
        }
    }
}

-(void)enableCaptureMode{
    
    NSUInteger i;
    for(i=1;i<9;i++){
        NSString *key=[NSString stringWithFormat:@"%lu",(unsigned long)i];
        NSWindow *window = [anchorWindows objectForKey:key];
        if (!window){
            window= [QSMouseTriggerView triggerWindowWithAnchor:i onScreenNum:0];
            [anchorWindows setObject:window forKey:key];
			// if (VERBOSE)NSLog(@"Creating anchor window %d",i);
            [[window contentView]setToolTip:nil];
        }
        
        [window setIgnoresMouseEvents:NO];
        [window orderFront:self];
        [[window contentView]setCaptureMode:YES];
        
    }
    
}


-(void)disableCaptureMode{
    NSUInteger i;
    for(i=1;i<9;i++){
        NSWindow *window=[anchorWindows objectForKey:[NSString stringWithFormat:@"%lu",(unsigned long)i]];
        [[window contentView]setCaptureMode:NO];
        
    }
    [self updateTriggerWindows];
}

- (NSView *) settingsView{
    if (!settingsView){
        [NSBundle loadNibNamed:@"QSMouseTrigger" owner:self];		
	}
	//	NSLog(@"sview %@",settingsView);
    return [[settingsView retain] autorelease];
}



- (void)populateInfoFields{
	//NSLog(@"trigger %@",currentTrigger);
	if([[currentTrigger type] isEqualToString:@"QSMouseTrigger"]){
		NSEventType eventType=[[[currentTrigger info] objectForKey:@"eventType"] unsignedIntegerValue];
		BOOL otherClick=eventType==NSOtherMouseDown;
		
		NSUInteger modifiersMask=[[[currentTrigger info] objectForKey:@"modifierFlags"]unsignedIntegerValue];
		BOOL anywhere=[[[currentTrigger info] objectForKey:@"anywhere"]boolValue] && (otherClick);
		
		[mouseTriggerScreenPopUp removeAllItems];
		NSMenuItem *item=[[mouseTriggerScreenPopUp menu] addItemWithTitle:@"All Displays" action:nil keyEquivalent:@""];
		[item setTag:-1];
		
		item=[NSMenuItem separatorItem];
		[item setTag:NSNotFound];
		[[mouseTriggerScreenPopUp menu]addItem:item];
		
		item=	[[mouseTriggerScreenPopUp menu] addItemWithTitle:@"Main Display" action:nil keyEquivalent:@""];
		[item setTag:0];
		item=	[[mouseTriggerScreenPopUp menu] addItemWithTitle:@"Secondary Display" action:nil keyEquivalent:@""];
		[item setTag:1];
		
		item=[NSMenuItem separatorItem];
		[item setTag:NSNotFound];
		[[mouseTriggerScreenPopUp menu]addItem:item];
		
		item=[[mouseTriggerScreenPopUp menu] addItemWithTitle:@"Specific Displays:" action:nil keyEquivalent:@""];
		[item setTarget:nil];
		
		NSEnumerator *e=[[NSScreen screens]objectEnumerator];
		NSScreen *screen;
		while(screen=[e nextObject]){
			NSString *name=[screen deviceName];
			name=[name stringByAppendingString:[[NSString stringWithFormat:@" (%x)",[screen screenNumber]]uppercaseString]];
			
			[[mouseTriggerScreenPopUp menu] addItemWithTitle:name action:nil keyEquivalent:@""];
			
			[item setTag:[screen screenNumber]];
		}
		
		int screenNum= [[[currentTrigger info] objectForKey:@"screen"]intValue];
		if (anywhere)screenNum=-1;
		[mouseTriggerScreenPopUp setEnabled:!anywhere];
		item=[[mouseTriggerScreenPopUp menu]itemWithTag:screenNum];
		if (!item){
			item=[[mouseTriggerScreenPopUp menu] addItemWithTitle:[NSString stringWithFormat:@"Other (%d)",screenNum] action:nil keyEquivalent:@""];
			[item setTag:screenNum];	
		}
		[mouseTriggerScreenPopUp selectItem:item];
		
		NSArray *screens=[NSScreen screens];
		
		if (screenNum==1 && [screens count]>1)
			screenNum=[[[NSScreen screens]objectAtIndex:1]screenNumber];		
		if (screenNum<=0)
			screenNum=[[screens objectAtIndex:0]screenNumber];
		
		[desktopImageView setScreenNumber:screenNum];
		
		
		[menuBarAnchorButton setEnabled:screenNum];
		
		
		
		
		
		BOOL clickEvent=(eventType==NSLeftMouseDown || eventType==NSRightMouseDown || eventType==NSOtherMouseDown);
		
		if (eventType==NSOtherMouseDown)
			eventType+= (NSUInteger)[[[currentTrigger info] objectForKey:@"buttonNumber"] integerValue]-3;
		
		NSInteger index=[mouseTriggerTypePopUp indexOfItemWithTag:eventType];
		//NSLog(@"type %@ %d %d",mouseTriggerTypePopUp,eventType,index);
		[mouseTriggerTypePopUp selectItemAtIndex:index];
		
		[anywhereButton setState:anywhere];
		[anywhereButton setHidden:!is1043 || (!otherClick && !modifiersMask)];
		NSUInteger anchorMask= [[[currentTrigger info] objectForKey:@"anchorMask"]unsignedIntegerValue];
		
		NSInteger i;
		for (i=1;i<9;i++){
			[[anchorView viewWithTag:i] setState:(anchorMask&(1<<i))];
			[[anchorView viewWithTag:i] setEnabled:!anywhere];
			
		}
		
		
		for (i=17;i<24;i++){
			//  NSLog(@"%@ %d %d",[modifiersView viewWithTag:i],modifiersMask,(modifiersMask&(1<<i)));
			[[modifiersView viewWithTag:i]setState:(modifiersMask&(1<<i))];
		}
		
		NSInteger clickCount=MAX(1,[[[currentTrigger info] objectForKey:@"clickCount"]integerValue]);
		[mouseTriggerClickCountField setIntegerValue:clickCount];
		[mouseTriggerClickCountStepper setIntegerValue:clickCount];
		
		
		[mouseTriggerClickCountField setHidden:!clickEvent];
		[mouseTriggerClickCountStepper setHidden:!clickEvent];
		
		BOOL delayableEvent=clickEvent || (eventType==NSMouseEntered);
		NSNumber *delay=[[currentTrigger info] objectForKey:@"delay"];
		[mouseTriggerDelaySwitch setEnabled:delayableEvent];
		[mouseTriggerDelaySwitch setState:delay && delayableEvent];
		
		[mouseTriggerDelayField setEnabled: delay && delayableEvent];
		[mouseTriggerDelayField setObjectValue:delay];
		
		//        IBOutlet NSTextField *mouseTriggerDelayField;
		
		// IBOutlet NSView *modifiersView;
	}	
}

- (IBAction) setMouseTriggerModifierFlag:(id)sender{
	
	NSUInteger mask=[[[currentTrigger info] objectForKey:@"modifierFlags"] unsignedIntegerValue];
	
	if ([(NSButton *)sender state])
		mask |= 1<<[sender tag];
	else
		mask &= ~(1<<[sender tag]);
	
	//NSLog(@" %d",mask);
	[[currentTrigger info] setObject:[NSNumber numberWithInteger:mask] forKey:@"modifierFlags"];
	[[QSTriggerCenter sharedInstance] triggerChanged:currentTrigger];
	//	[triggerTable reloadData];
	[self populateInfoFields];
}

-(BOOL)isMainDisplay {
    NSArray *screens = [self screensForScreenTag:[[currentTrigger objectForKey:@"screen"] integerValue]];
    if ([screens count] > 1) {
        return NO;
    }
    return [[screens lastObject] isEqual:[NSScreen mainScreen]];
}

- (IBAction) setMouseTriggerValueForSender:(id)sender{
	id nextResponder=nil;
	if (sender==mouseTriggerClickCountStepper){
		[[currentTrigger info] setObject:[sender objectValue] forKey:@"clickCount"];
	}else if (sender==mouseTriggerDelaySwitch){
		
		if ([(NSButton *)sender state]){
			[[currentTrigger info] setObject:[NSNumber numberWithDouble:0.5] forKey:@"delay"];
			nextResponder=mouseTriggerDelayField;
		}else{
			[[currentTrigger info] removeObjectForKey:@"delay"];
		}
		
	}else if (sender==mouseTriggerDelayField){
		CGFloat delay=[sender doubleValue];
		
		if (delay>0)
			[[currentTrigger info] setObject:[NSNumber numberWithDouble:delay] forKey:@"delay"];
		else
			[[currentTrigger info] removeObjectForKey:@"delay"];
	}else if (sender==mouseTriggerScreenPopUp){
		
		[[currentTrigger info] setObject:[NSNumber numberWithInteger:[[sender selectedItem]tag]] forKey:@"screen"];
		//	NSLog(@"Screen set to: %x",[[sender selectedItem]tag]);
	}else if (sender==anywhereButton){
		[[currentTrigger info] setObject:[sender objectValue] forKey:@"anywhere"];
        NSLog(@"%@",[sender objectValue]);
        if ([sender objectValue]) {
            // When the 'anywhere' button is pressed, make the text bold to show that it's activated
            [anywhereButton setFont:[NSFont boldSystemFontOfSize:[[anywhereButton font] pointSize]]];
        }
	}
	[[QSTriggerCenter sharedInstance] triggerChanged:currentTrigger];
	[self populateInfoFields];
	if (nextResponder)
		[[sender window]makeFirstResponder:nextResponder];
}

- (IBAction) setMouseTriggerAnchorMask:(id)sender{
	
	NSUInteger mask=[[[currentTrigger info] objectForKey:@"anchorMask"] unsignedIntegerValue];
	
	if ([(NSButton *)sender state])
		mask |= 1<<[sender tag];
	else
		mask &= ~(1<<[sender tag]);
	
	[[currentTrigger info] setObject:[NSNumber numberWithUnsignedInteger:mask] forKey:@"anchorMask"];
	[[QSTriggerCenter sharedInstance] triggerChanged:currentTrigger];
	//	[triggerTable reloadData];
}
- (IBAction) setMouseTriggerType:(id)sender{
	
	NSInteger eventType=[[sender selectedItem]tag];
	NSInteger buttonNumber=0;
	switch (eventType){
		case 25: buttonNumber=3; break;
		case 26: eventType=25; buttonNumber=4; break;
		case 27: eventType=25; buttonNumber=5; break;
		default: break;
	}
	
	[[currentTrigger info] setObject:[NSNumber numberWithInteger:eventType] forKey:@"eventType"];
	if (buttonNumber)
		[[currentTrigger info] setObject:[NSNumber numberWithInteger:buttonNumber] forKey:@"buttonNumber"];
	[[QSTriggerCenter sharedInstance] triggerChanged:currentTrigger];
	//	[triggerTable reloadData];
	[self populateInfoFields];
}

- (void)applicationDidChangeScreenParameters:(NSNotification *)aNotification{
	//NSLog(@"screen change!");
	[anchorArrays removeAllObjects];
	[anchorWindows removeAllObjects];
	for(NSDictionary * trigger in [[QSTriggerCenter sharedInstance]triggers]){
		if ([[trigger objectForKey:@"type"]isEqualToString:@"QSMouseTrigger"]){
			[self disableTrigger:trigger];
			[self enableTrigger:trigger];
		}
	}
	
}

-(id)resolveProxyObject:(id)proxy{
	
	return [self mouseTriggerObject];
}

-(NSArray *)typesForProxyObject:(id)proxy{
	return [[self mouseTriggerObject] types];
}


- (id)mouseTriggerObject {
    return [[mouseTriggerObject retain] autorelease];
}

- (void)setMouseTriggerObject:(id)newMouseTriggerObject
{
    [mouseTriggerObject autorelease];
    mouseTriggerObject = [newMouseTriggerObject retain];
}

@end





