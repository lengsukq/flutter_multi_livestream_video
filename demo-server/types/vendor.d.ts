declare module 'agora-token' {
  const agoraToken: {
    RtcRole: {
      PUBLISHER: number;
      SUBSCRIBER: number;
    };
    RtcTokenBuilder: {
      buildTokenWithUid(
        appId: string,
        appCertificate: string,
        channelName: string,
        uid: number,
        role: number,
        tokenExpire: number,
        privilegeExpire: number,
      ): string;
    };
  };
  export default agoraToken;
}

declare module 'tls-sig-api-v2' {
  class Api {
    constructor(sdkAppId: number, secretKey: string);
    genSig(userId: string, expire: number): string;
    genPrivateMapKeyWithStringRoomID(
      userId: string,
      expire: number,
      roomId: string,
      privilegeMap: number,
    ): string;
  }

  const tlsSigApiV2: { Api: typeof Api };
  export default tlsSigApiV2;
}
