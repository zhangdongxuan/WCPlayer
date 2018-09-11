//
//  WCPlayerMediaCore.m
//  WCPlayer
//
//  Created by Kina on 2018/9/9.
//  Copyright © 2018 zdx. All rights reserved.
//

#import "WCPlayerDecoder.h"
#include <libavutil/imgutils.h>
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libswscale/swscale.h>

@implementation WCPlayerDecoder

-(void)startDecoder{
    /** 1. 解封装: 打开封装格式 */
    /** 2. 查找视频（音频）流 */
    
    const char *file_name = [[[NSBundle mainBundle] pathForResource:@"test" ofType:@"mp4"] UTF8String];
    
    AVFormatContext *fmt_ctx = NULL;
    
    AVCodecContext *video_dec_ctx = NULL;
    AVCodecContext *audio_dec_ctx = NULL;
    
    AVCodecParameters  *videoParams = NULL;
    AVCodecParameters  *audioParams = NULL;
    
    AVStream *video_stream = NULL;
    AVStream *audio_stream = NULL;
    
    int video_stream_idx = -1;
    int audio_stream_idx = -1;
    
    /** 1. 解封装: 打开封装格式 */
    /* open input file, and allocate format context */
    if (avformat_open_input(&fmt_ctx, file_name, NULL, NULL) < 0) {
        fprintf(stderr, "Could not open source file %s\n", file_name);
        return;
    }
    
    int64_t duration = fmt_ctx->duration;
    int64_t bit_rate = fmt_ctx->bit_rate;
    unsigned int nb_streams = fmt_ctx->nb_streams;
    const char *format_name = fmt_ctx->iformat->long_name;
    
    NSLog(@"duration:%lld bit_rate:%lld nb_streams:%u", duration, bit_rate, nb_streams);
    NSLog(@"format:%s", format_name);
    
    /** 3. 查找视频（音频）流 */
    /* retrieve stream information */
    if (avformat_find_stream_info(fmt_ctx, NULL) < 0) {
        fprintf(stderr, "Could not find stream information\n");
        return;
    }
    
    /** 初始化解码器上下文 */
    if (open_codec_context(&video_stream_idx, &video_dec_ctx, fmt_ctx, file_name,AVMEDIA_TYPE_VIDEO) >= 0) {
        video_stream = fmt_ctx->streams[video_stream_idx];
    }
    
    if (open_codec_context(&audio_stream_idx, &audio_dec_ctx, fmt_ctx, file_name, AVMEDIA_TYPE_AUDIO) >= 0) {
        audio_stream = fmt_ctx->streams[audio_stream_idx];
    }
    
    if(video_stream == NULL){
        fprintf(stderr, "cant get right video decoder");
        return;
    }

    if (audio_stream == NULL) {
        fprintf(stdout, "cant get right video decoder");
    }

    videoParams = video_stream->codecpar;
    audioParams = audio_stream->codecpar;

    int width = videoParams->width;
    int height = videoParams->height;

    NSLog(@"width:%d height:%d", width, height);
    NSLog(@"format:%d", videoParams->format);
    NSLog(@"codeId:%d", videoParams->codec_id);
    NSLog(@"video with:%d", video_dec_ctx->width);
    NSLog(@"video codec:%s", video_dec_ctx->codec->name);
    NSLog(@"audio codec:%s", audio_dec_ctx->codec->name);
    
    struct SwsContext *sws_ctx = sws_getContext(width, height, video_dec_ctx->pix_fmt, width, height, AV_PIX_FMT_YUV420P, SWS_BICUBIC, NULL, NULL, NULL);


    AVFrame* avframe_yuv420p = av_frame_alloc();

    int buffer_size = av_image_get_buffer_size(AV_PIX_FMT_YUV420P, width, height, 1);
    uint8_t *out_buffer = (uint8_t *)av_malloc(buffer_size);

    av_image_fill_arrays(avframe_yuv420p->data, avframe_yuv420p->linesize, out_buffer, AV_PIX_FMT_YUV420P, width, height, 1);

    /** 循环读取视频压缩数据->循环读取 */
    int decode_ret = 0;
    AVFrame *origin_frame = av_frame_alloc();
    AVPacket *packet = (AVPacket *)av_malloc(sizeof(AVPacket));

    int y_size, u_size, v_size;
    int current_index = 0;
    while (av_read_frame(fmt_ctx, packet) >= 0) {
        if (packet->stream_index == video_stream_idx) {
            /** 解码出一帧视频压缩数据，并对压缩数据进行解码 */
            avcodec_send_packet(video_dec_ctx, packet);
            decode_ret = avcodec_receive_frame(video_dec_ctx, origin_frame);
            if (decode_ret == 0) {
                /**
                 * 解码成功
                 * 数据格式 AVPixelFormat有很多种。
                 * 这里需要将像素格式统一转换为yuv420p
                 */
                // int sws_scale(struct SwsContext *c, const uint8_t *const srcSlice[], const int srcStride[], int srcSliceY, int srcSliceH,
                // uint8_t *const dst[], const int dstStride[]);
                //参数一：视频像素数据格式上下文
                //参数二：原来的视频像素数据格式->输入数据
                //参数三：原来的视频像素数据格式->输入画面每一行大小
                //参数四：原来的视频像素数据格式->输入画面每一行开始位置(填写：0->表示从原点开始读取)
                //参数五：原来的视频像素数据格式->输入数据行数
                //参数六：转换类型后视频像素数据格式->输出数据
                //参数七：转换类型后视频像素数据格式->输出画面每一行大小

                const uint8_t *const *data = (const uint8_t *const *)origin_frame->data;
                sws_scale(sws_ctx, data, origin_frame->linesize, 0, height, avframe_yuv420p->data, avframe_yuv420p->linesize);

                y_size = width * height;
                u_size = y_size / 4;
                v_size = y_size / 4;

//                fwrite(avframe_yuv420p->data[0], 1, y_size, file_yuv420p);
//                //其次->U数据
//                fwrite(avframe_yuv420p->data[1], 1, u_size, file_yuv420p);
//                //再其次->V数据
//                fwrite(avframe_yuv420p->data[2], 1, v_size, file_yuv420p);

                current_index++;
                printf("第%d帧\n", current_index);
            }
        }
    }

    av_packet_free(&packet);
    av_frame_free(&origin_frame);
    av_frame_free(&avframe_yuv420p);
    free(out_buffer);
    avcodec_close(video_dec_ctx);
    avcodec_close(audio_dec_ctx);
    avformat_free_context(fmt_ctx);
}

int open_codec_context(int *stream_idx, AVCodecContext **dec_ctx, AVFormatContext *fmt_ctx, const char *file_name, enum AVMediaType type) {

    int best_stream_index = av_find_best_stream(fmt_ctx, type, -1, -1, NULL, 0);
    if (best_stream_index == AVERROR_STREAM_NOT_FOUND || best_stream_index == AVERROR_DECODER_NOT_FOUND) {
        fprintf(stderr, "Could not find %s stream in input file '%s'\n", av_get_media_type_string(type), file_name);
        return best_stream_index;
    }
    else {

        AVStream *stream= fmt_ctx->streams[best_stream_index];

        /* find decoder for the stream */
        AVCodec *codec = avcodec_find_decoder(stream->codecpar->codec_id);
        if (codec == NULL) {
            fprintf(stderr, "Failed to find %s codec\n", av_get_media_type_string(type));
            return AVERROR(EINVAL);
        }

        /* Allocate a codec context for the decoder */
        *dec_ctx = avcodec_alloc_context3(codec);
        if (*dec_ctx == NULL) {
            fprintf(stderr, "Failed to allocate the %s codec context\n", av_get_media_type_string(type));
            return AVERROR(ENOMEM);
        }

        /* Copy codec parameters from input stream to output codec context */
        int ret = avcodec_parameters_to_context(*dec_ctx, stream->codecpar);
        if (ret < 0) {
            fprintf(stderr, "Failed to copy %s codec parameters to decoder context\n", av_get_media_type_string(type));
            return ret;
        }


        /* Init the decoders, with or without reference counting */
        AVDictionary *opts = NULL;
        av_dict_set(&opts, "refcounted_frames", "0", 0);
        ret = avcodec_open2(*dec_ctx, codec, &opts);
        if (ret < 0) {
            fprintf(stderr, "Failed to open %s codec\n", av_get_media_type_string(type));
            return ret;
        }

        *stream_idx = best_stream_index;
    }

    return 0;
}


@end
