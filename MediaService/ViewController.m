//
//  ViewController.m
//  MediaService
//
//  Created by chenjiannan on 2018/6/22.
//  Copyright © 2018年 chenjiannan. All rights reserved.
//

#import "ViewController.h"
#import "VPVideoStreamPlayLayer.h"
#import "VEVideoEncoder.h"
#import "H264Decoder.h"
#import "VCVideoCapturer.h"
#import "MetalPlayer.h"

#define USED_METAL

@interface ViewController () <H264DecoderDelegate, VEVideoEncoderDelegate, VCVideoCapturerDelegate, GCDAsyncSocketDelegate>

/** 视频流播放器 */
#ifdef USED_METAL
@property (nonatomic, strong) MetalPlayer *playLayer;
#else
@property (nonatomic, strong) VPVideoStreamPlayLayer *playLayer;
#endif
/** 解码播放视图 */
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *recordLayer;

/** H264解码器 */
@property (nonatomic, strong) H264Decoder *h264Decoder;
/** 视频采集 */
@property (nonatomic, strong) VCVideoCapturer *videoCapture;
/** 视频编码器 */
@property (nonatomic, strong) VEVideoEncoder *videoEncoder;

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor whiteColor];
    
    // 初始化视频采集
    VCVideoCapturerParam *param = [[VCVideoCapturerParam alloc] init];
    param.sessionPreset = AVCaptureSessionPreset1280x720;
    
    self.videoCapture = [[VCVideoCapturer alloc] initWithCaptureParam:param error:nil];
    self.videoCapture.delegate = self;
    
    // 初始化并开启视频编码
    VEVideoEncoderParam *encodeParam = [[VEVideoEncoderParam alloc] init];
    encodeParam.encodeWidth = 180;
    encodeParam.encodeHeight = 320;
    encodeParam.bitRate = 512 * 1024;
    _videoEncoder = [[VEVideoEncoder alloc] initWithParam:encodeParam];
    _videoEncoder.delegate = self;
    [_videoEncoder startVideoEncode];
    
    // 初始化视频解码
    self.h264Decoder = [[H264Decoder alloc] init];
    self.h264Decoder.delegate = self;
    
    
    CGFloat layerMargin = 15;
    CGFloat layerW = (self.view.frame.size.width - 3 * layerMargin) * 0.5;
    CGFloat layerH = layerW * 16 / 9.00;
    CGFloat layerY = 120;
    
    // 初始化视频采集的预览画面
    self.recordLayer = self.videoCapture.videoPreviewLayer;
    self.recordLayer.frame = CGRectMake(layerMargin, layerY, layerW, layerH);

    // 初始化视频编码解码后的播放画面
#ifdef USED_METAL
    self.playLayer = [[MetalPlayer alloc] initWithFrame:CGRectMake(layerMargin * 2 + layerW, layerY, layerW, layerH)];
#else
    self.playLayer = [[VPVideoStreamPlayLayer alloc] initWithFrame:CGRectMake(layerMargin * 2 + layerW, layerY, layerW, layerH)];
#endif
    self.playLayer.backgroundColor = [UIColor blackColor].CGColor;
    
    CGFloat buttonW = self.view.frame.size.width * 0.4;
    CGFloat buttonH = 40;
    CGFloat buttonMargin = (self.view.frame.size.width - buttonW * 2) / 3.0;
    CGFloat buttonY = 60;
    
    UIButton *cameraButton = [[UIButton alloc] initWithFrame:CGRectMake(buttonMargin, buttonY, buttonW, buttonH)];
    [cameraButton setTitle:@"开启/关闭 摄像头" forState:UIControlStateNormal];
    [cameraButton setBackgroundColor:[UIColor lightGrayColor]];
    [cameraButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [cameraButton addTarget:self action:@selector(cameraButtonAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:cameraButton];
    
    UIButton *revertCameraButton = [[UIButton alloc] initWithFrame:CGRectMake(buttonMargin * 2 + buttonW, buttonY, buttonW, buttonH)];
    [revertCameraButton setTitle:@"切换摄像头" forState:UIControlStateNormal];
    [revertCameraButton setBackgroundColor:[UIColor lightGrayColor]];
    [revertCameraButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    [revertCameraButton addTarget:self action:@selector(revertCameraButtonAction:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:revertCameraButton];
    [self configSocket];
}

- (void)configSocket {
    socketQueue = dispatch_queue_create("socketQueue", NULL);
    
    listenSocket = [[GCDAsyncSocket alloc] initWithDelegate:self delegateQueue:socketQueue];
    
    int port = 2345;
    NSError *error = nil;
    if(![listenSocket acceptOnPort:port error:&error])
    {
        NSLog(@"error starting server %@",error);
        return;
    } else {
        NSLog(@"starting server");
    }
}

- (void)cameraButtonAction:(UIButton *)button
{
    button.selected = !button.selected;
    if (button.selected)
    {
        [self.videoCapture startCapture];
        [self.view.layer addSublayer:self.recordLayer];
        [self.view.layer addSublayer:self.playLayer];
    }
    else
    {
        [self.videoCapture stopCapture];
        [self.videoCapture.videoPreviewLayer removeFromSuperlayer];
        [self.playLayer removeFromSuperlayer];
    }
}

- (void)revertCameraButtonAction:(UIButton *)button
{
    [self.videoCapture reverseCamera];
}



#pragma mark - 视频采集回调
- (void)videoCaptureOutputDataCallback:(CMSampleBufferRef)sampleBuffer
{
    [self.videoEncoder videoEncodeInputData:sampleBuffer forceKeyFrame:NO];
}

#pragma mark - H264编码回调
- (void)videoEncodeOutputDataCallback:(NSData *)data isKeyFrame:(BOOL)isKeyFrame
{
    
//    NSString *str = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
//    if (str != nil) {
//        str = [NSString stringWithFormat:@"%@", "|"];
//        NSData *da = [str dataUsingEncoding:NSUTF8StringEncoding];
//    NSDictionary
        [connectSocket writeData:data withTimeout:-1 tag:0];
    NSString *msg = @"|#|";
    NSData *msgData = [msg dataUsingEncoding:NSUTF8StringEncoding];
    [connectSocket writeData:msgData withTimeout:-1 tag:0];
        NSLog(@"上报");
//    }
//    [self.h264Decoder decodeNaluData:data];
//    [connectSocket readDataWithTimeout:-1 tag:0];
}

#pragma mark - H264解码回调
- (void)videoDecodeOutputDataCallback:(CVImageBufferRef)imageBuffer
{
    NSLog(@"解码回调");
    [self.playLayer inputPixelBuffer:imageBuffer];
    CVPixelBufferRelease(imageBuffer);
}

#pragma mark - Socket 回调
- (void)socket:(GCDAsyncSocket *)sock didAcceptNewSocket:(GCDAsyncSocket *)newSocket
{
    // This method is executed on the socketQueue (not the main thread)
    connectSocket = newSocket;
    [newSocket readDataWithTimeout: -1 tag: 0];

    
}

- (void)socketDidDisconnect:(GCDAsyncSocket *)sock withError:(NSError *)err
{
    if (sock != listenSocket)
    {
        NSLog(@"client disconnected");
    }
}

- (void)socket:(GCDAsyncSocket *)sock didReadData:(NSData *)data withTag:(long)tag{
//    NSLog(@"接收到tag = %ld : %ld 长度的数据",tag,data.length);
//    NSLog(@"接受到的数据内容为：%@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
//
//    //连接成功或者收到消息，必须开始read，否则将无法收到消息
//    //不read的话，缓存区将会被关闭
//    // -1 表示无限时长 ， tag
//    for ( GCDAsyncSocket *socket in connectedSockets ) {
//        [socket readDataWithTimeout:-1 tag:0];
//    }
    [connectSocket readDataWithTimeout:-1 tag:0];
    [self.h264Decoder decodeNaluData:data];
}
@end
