//
//  ViewController.h
//  MediaService
//
//  Created by chenjiannan on 2018/6/22.
//  Copyright © 2018年 chenjiannan. All rights reserved.
//

#import <UIKit/UIKit.h>
//#import "GC"
#import "GCDAsyncSocket.h"

@interface ViewController : UIViewController {
    dispatch_queue_t socketQueue;
    
    GCDAsyncSocket *listenSocket;
    GCDAsyncSocket *connectSocket;
//    NSMutableArray *connectedSockets;

}


@end

