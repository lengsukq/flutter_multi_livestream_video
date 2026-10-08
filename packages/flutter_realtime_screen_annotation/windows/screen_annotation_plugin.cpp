#include "include/flutter_realtime_screen_annotation/flutter_realtime_screen_annotation_plugin_c_api.h"
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>
#include <windows.h>
#include <windowsx.h>
#include <gdiplus.h>
#include <algorithm>
#include <cmath>
#include <map>
#include <memory>
#include <string>
#include <stdexcept>
#include <vector>
using V=flutter::EncodableValue; using M=flutter::EncodableMap; using L=flutter::EncodableList;
static const V& get(const M& m,const char* k){static V empty;auto i=m.find(V(k));return i==m.end()?empty:i->second;}
static std::string str(const V& v){auto p=std::get_if<std::string>(&v);return p?*p:"";}
static double num(const V& v){if(auto p=std::get_if<double>(&v))return *p;if(auto p=std::get_if<int32_t>(&v))return *p;if(auto p=std::get_if<int64_t>(&v))return static_cast<double>(*p);return 0;}
static std::wstring wide(const std::string& s){int n=MultiByteToWideChar(CP_UTF8,0,s.data(),static_cast<int>(s.size()),nullptr,0);std::wstring r(n,L' ');MultiByteToWideChar(CP_UTF8,0,s.data(),static_cast<int>(s.size()),r.data(),n);return r;}
static std::string utf8(const std::wstring& s){int n=WideCharToMultiByte(CP_UTF8,0,s.data(),static_cast<int>(s.size()),nullptr,0,nullptr,nullptr);std::string r(n,' ');WideCharToMultiByte(CP_UTF8,0,s.data(),static_cast<int>(s.size()),r.data(),n,nullptr,nullptr);return r;}
class ScreenAnnotationPlugin : public flutter::Plugin {
 std::unique_ptr<flutter::MethodChannel<V>> channel;
 HWND canvas=nullptr,bar=nullptr,dialog=nullptr,input=nullptr;
 HDC paintDC=nullptr; HBITMAP paintDib=nullptr; HGDIOBJ previousDib=nullptr; void* paintBits=nullptr;
 ULONG_PTR gdiplus=0; std::string session,tool="pen"; L shapes;std::map<std::string,M> drafts;M stroke;
 bool drawing=false,failed=false;int x=0,y=0,w=0,h=0; ULONGLONG emitted=0; uint64_t nextId=0;
 static L& points(M& s){return std::get<L>(s[V("points")]);}
 void event(const char* type,M extra={}){if(session.empty())return;extra[V("type")]=V(type);extra[V("sessionId")]=V(session);channel->InvokeMethod("event",std::make_unique<V>(extra));}
 M position(int px,int py){return {{V("x"),V(std::clamp(px/static_cast<double>(w),0.0,1.0))},{V("y"),V(std::clamp(py/static_cast<double>(h),0.0,1.0))}};}
 void emit(bool done){if(stroke.empty())return;event("stroke",{{V("shape"),V(stroke)},{V("finished"),V(done)}});emitted=GetTickCount64();}
 void finish(){if(dialog)return;emit(true);stroke.clear();}
 void setDrawing(bool enabled){drawing=enabled;LONG_PTR style=GetWindowLongPtr(canvas,GWL_EXSTYLE);SetWindowLongPtr(canvas,GWL_EXSTYLE,enabled?(style&~WS_EX_TRANSPARENT):(style|WS_EX_TRANSPARENT));render();}
 void begin(int px,int py){if(failed||drafts.size()>=8)return;std::string id=session+"-"+std::to_string(++nextId);stroke={{V("id"),V(id)},{V("tool"),V(tool)},{V("color"),V(static_cast<int64_t>(tool=="highlight"?0xffffeb3bULL:0xfff59e0bULL))},{V("width"),V(tool=="highlight"?16:3)},{V("text"),V("")},{V("points"),V(L{V(position(px,py))})}};drafts[id]=stroke;
  if(tool=="text"){showText();}else emit(false);render();}
 void move(int px,int py){if(stroke.empty()||points(stroke).size()>=2048)return;auto& ps=points(stroke);if(tool!="pen"&&tool!="highlight"&&ps.size()>1)ps.pop_back();ps.emplace_back(position(px,py));drafts[str(get(stroke,"id"))]=stroke;if(GetTickCount64()-emitted>=100)emit(false);render();}
 void showText(){dialog=CreateWindowEx(WS_EX_TOPMOST,L"MultiLiveAnnotation",L"Label",WS_OVERLAPPED|WS_CAPTION|WS_SYSMENU,x+20,y+100,360,135,bar,nullptr,GetModuleHandle(nullptr),this);input=CreateWindowEx(WS_EX_CLIENTEDGE,L"EDIT",L"",WS_CHILD|WS_VISIBLE|ES_AUTOHSCROLL,10,10,320,28,dialog,reinterpret_cast<HMENU>(101),nullptr,nullptr);SendMessage(input,EM_SETLIMITTEXT,200,0);CreateWindow(L"BUTTON",L"Add",WS_CHILD|WS_VISIBLE,230,48,100,28,dialog,reinterpret_cast<HMENU>(102),nullptr,nullptr);ShowWindow(dialog,SW_SHOW);SetFocus(input);}
 void cancelLabel(){if(!stroke.empty())drafts.erase(str(get(stroke,"id")));stroke.clear();if(dialog){HWND old=dialog;dialog=nullptr;DestroyWindow(old);}render();}
 void render(){if(!canvas||w<=0||h<=0)return;HDC screen=GetDC(nullptr);if(!paintDC){paintDC=CreateCompatibleDC(screen);BITMAPINFO info={};info.bmiHeader.biSize=sizeof(BITMAPINFOHEADER);info.bmiHeader.biWidth=w;info.bmiHeader.biHeight=-h;info.bmiHeader.biPlanes=1;info.bmiHeader.biBitCount=32;info.bmiHeader.biCompression=BI_RGB;paintDib=CreateDIBSection(screen,&info,DIB_RGB_COLORS,&paintBits,nullptr,0);if(!paintDib){DeleteDC(paintDC);paintDC=nullptr;ReleaseDC(nullptr,screen);return;}previousDib=SelectObject(paintDC,paintDib);}
  {Gdiplus::Bitmap bitmap(w,h,w*4,PixelFormat32bppPARGB,static_cast<BYTE*>(paintBits));Gdiplus::Graphics g(&bitmap);g.Clear(Gdiplus::Color(drawing?1:0,0,0,0));g.SetSmoothingMode(Gdiplus::SmoothingModeAntiAlias);float scale=std::min(w,h)/720.0f;
   auto paint=[&](const M& s){auto ps=std::get_if<L>(&get(s,"points"));if(!ps||ps->empty())return;std::vector<Gdiplus::PointF> p;for(const V& v:*ps){const M& m=std::get<M>(v);p.emplace_back(static_cast<float>(num(get(m,"x"))*w),static_cast<float>(num(get(m,"y"))*h));}std::string t=str(get(s,"tool"));uint32_t c=static_cast<uint32_t>(num(get(s,"color")));Gdiplus::Color color(t=="highlight"?89:255,(c>>16)&255,(c>>8)&255,c&255);Gdiplus::Pen pen(color,std::max(1.0f,static_cast<float>(num(get(s,"width")))*scale));pen.SetStartCap(Gdiplus::LineCapRound);pen.SetEndCap(Gdiplus::LineCapRound);auto a=p.front(),b=p.back();
    if(t=="text"){Gdiplus::Font font(L"Segoe UI",std::max(10.0f,22*scale),Gdiplus::FontStyleRegular,Gdiplus::UnitPixel);Gdiplus::SolidBrush brush(color);auto text=wide(str(get(s,"text")));g.DrawString(text.c_str(),-1,&font,a,&brush);}
    else if(t=="circle")g.DrawEllipse(&pen,std::min(a.X,b.X),std::min(a.Y,b.Y),std::abs(a.X-b.X),std::abs(a.Y-b.Y));
    else if(t=="arrow"){g.DrawLine(&pen,a,b);double angle=std::atan2(b.Y-a.Y,b.X-a.X),len=std::max(8.0f,18*scale);for(double d:{-.5,.5})g.DrawLine(&pen,b,Gdiplus::PointF(static_cast<float>(b.X-std::cos(angle+d)*len),static_cast<float>(b.Y-std::sin(angle+d)*len)));}
    else if(p.size()==1){Gdiplus::SolidBrush brush(color);float r=pen.GetWidth();g.FillEllipse(&brush,a.X-r/2,a.Y-r/2,r,r);}else g.DrawLines(&pen,p.data(),static_cast<int>(p.size()));};
   for(const V& s:shapes){const M& m=std::get<M>(s);if(!drafts.count(str(get(m,"id"))))paint(m);}for(const auto& d:drafts)paint(d.second);
  }
  POINT origin={x,y},zero={0,0};SIZE size={w,h};BLENDFUNCTION blend={AC_SRC_OVER,0,255,AC_SRC_ALPHA};UpdateLayeredWindow(canvas,screen,&origin,&size,paintDC,&zero,0,&blend,ULW_ALPHA);ReleaseDC(nullptr,screen);
 }
 static LRESULT CALLBACK procedure(HWND window,UINT msg,WPARAM wp,LPARAM lp){auto* self=reinterpret_cast<ScreenAnnotationPlugin*>(GetWindowLongPtr(window,GWLP_USERDATA));if(msg==WM_NCCREATE){auto* cs=reinterpret_cast<CREATESTRUCT*>(lp);self=static_cast<ScreenAnnotationPlugin*>(cs->lpCreateParams);SetWindowLongPtr(window,GWLP_USERDATA,reinterpret_cast<LONG_PTR>(self));}if(!self)return DefWindowProc(window,msg,wp,lp);
  if(window==self->canvas){if(msg==WM_LBUTTONDOWN){SetCapture(window);self->begin(GET_X_LPARAM(lp),GET_Y_LPARAM(lp));return 0;}if(msg==WM_MOUSEMOVE&&(wp&MK_LBUTTON)){self->move(GET_X_LPARAM(lp),GET_Y_LPARAM(lp));return 0;}if(msg==WM_LBUTTONUP){ReleaseCapture();if(self->tool!="text")self->finish();return 0;}if(msg==WM_DISPLAYCHANGE||msg==WM_DPICHANGED){self->event("geometryChanged");self->close();return 0;}}
  if(msg==WM_COMMAND){int id=LOWORD(wp);if(window==self->dialog&&id==102){wchar_t text[201]={};GetWindowText(self->input,text,201);if(!text[0])return 0;self->stroke[V("text")]=V(utf8(text));self->drafts[str(get(self->stroke,"id"))]=self->stroke;self->emit(true);self->stroke.clear();HWND old=self->dialog;self->dialog=nullptr;DestroyWindow(old);self->render();return 0;}
   if(window==self->bar){if(self->dialog)return 0;self->finish();if(id==1)self->setDrawing(false);else if(id>=2&&id<=6){if(self->failed)return 0;self->tool=std::vector<std::string>{"pen","highlight","circle","arrow","text"}[id-2];self->setDrawing(true);}else if(id==7)self->event("undo");else if(id==8)self->event("clear");else if(id==9){self->event("closed");self->close();}return 0;}}
  if(msg==WM_CLOSE){if(window==self->dialog)self->cancelLabel();else{self->event("closed");self->close();}return 0;}return DefWindowProc(window,msg,wp,lp);
 }
 void close(){if(dialog){HWND old=dialog;dialog=nullptr;DestroyWindow(old);}if(bar){HWND old=bar;bar=nullptr;DestroyWindow(old);}if(canvas){HWND old=canvas;canvas=nullptr;DestroyWindow(old);}if(paintDC){SelectObject(paintDC,previousDib);DeleteObject(paintDib);DeleteDC(paintDC);paintDC=nullptr;paintDib=nullptr;paintBits=nullptr;}drafts.clear();shapes.clear();stroke.clear();session.clear();drawing=false;}
 void open(const M& args){close();session=str(get(args,"sessionId"));failed=false;const auto& v=std::get<M>(get(args,"viewport"));int dw=GetSystemMetrics(SM_CXSCREEN),dh=GetSystemMetrics(SM_CYSCREEN);x=static_cast<int>(num(get(v,"x"))*dw);y=static_cast<int>(num(get(v,"y"))*dh);w=static_cast<int>(num(get(v,"width"))*dw);h=static_cast<int>(num(get(v,"height"))*dh);shapes=std::get<L>(get(args,"shapes"));
  canvas=CreateWindowEx(WS_EX_TOPMOST|WS_EX_LAYERED|WS_EX_TRANSPARENT|WS_EX_TOOLWINDOW|WS_EX_NOACTIVATE,L"MultiLiveAnnotation",L"",WS_POPUP,x,y,w,h,nullptr,nullptr,GetModuleHandle(nullptr),this);
  bar=CreateWindowEx(WS_EX_TOPMOST|WS_EX_TOOLWINDOW,L"MultiLiveAnnotation",L"Screen annotations",WS_OVERLAPPED|WS_CAPTION|WS_SYSMENU,x+8,y+40,520,86,nullptr,nullptr,GetModuleHandle(nullptr),this);
  if(!canvas||!bar){close();throw std::runtime_error("Unable to create annotation windows");}
  const wchar_t* labels[]={L"Move",L"Pen",L"Highlight",L"Circle",L"Arrow",L"Text",L"Undo",L"Clear",L"Close"};for(int i=0;i<9;i++)CreateWindow(L"BUTTON",labels[i],WS_CHILD|WS_VISIBLE,3+i*56,8,54,30,bar,reinterpret_cast<HMENU>(static_cast<INT_PTR>(i+1)),nullptr,nullptr);
  ShowWindow(canvas,SW_SHOWNOACTIVATE);ShowWindow(bar,SW_SHOWNOACTIVATE);render();
 }
 public:
 explicit ScreenAnnotationPlugin(flutter::PluginRegistrarWindows* registrar){Gdiplus::GdiplusStartupInput config;Gdiplus::GdiplusStartup(&gdiplus,&config,nullptr);WNDCLASS cls={};cls.lpfnWndProc=procedure;cls.hInstance=GetModuleHandle(nullptr);cls.lpszClassName=L"MultiLiveAnnotation";cls.hCursor=LoadCursor(nullptr,IDC_CROSS);RegisterClass(&cls);
  channel=std::make_unique<flutter::MethodChannel<V>>(registrar->messenger(),"flutter_realtime_screen_annotation",&flutter::StandardMethodCodec::GetInstance());channel->SetMethodCallHandler([this](const flutter::MethodCall<V>& call,std::unique_ptr<flutter::MethodResult<V>> result){try{if(call.method_name()=="capabilities"){result->Success(V(M{{V("supported"),V(true)},{V("permissionRequired"),V(false)}}));return;}if(call.method_name()=="requestPermission"){result->Success(V(true));return;}const M& args=std::get<M>(*call.arguments());if(call.method_name()=="open")open(args);else if(str(get(args,"sessionId"))==session){if(call.method_name()=="close")close();else if(call.method_name()=="ack"){drafts.erase(str(get(args,"id")));render();}else if(call.method_name()=="update"){shapes=std::get<L>(get(args,"shapes"));failed=!std::holds_alternative<std::monostate>(get(args,"error"));if(failed){stroke.clear();drafts.clear();setDrawing(false);SetWindowText(bar,L"Sync failed: reopen tools");}render();}else{result->NotImplemented();return;}}result->Success();}catch(const std::exception& e){close();result->Error("system_annotation_failed",e.what());}});
 }
 ~ScreenAnnotationPlugin() override{channel->SetMethodCallHandler(nullptr);close();Gdiplus::GdiplusShutdown(gdiplus);}
};
void FlutterRealtimeScreenAnnotationPluginCApiRegisterWithRegistrar(FlutterDesktopPluginRegistrarRef registrar){auto* r=flutter::PluginRegistrarManager::GetInstance()->GetRegistrar<flutter::PluginRegistrarWindows>(registrar);r->AddPlugin(std::make_unique<ScreenAnnotationPlugin>(r));}
