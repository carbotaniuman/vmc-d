module osc.server;

import std.socket;
import std.container;
import core.thread;
import core.sync.mutex;
import osc.message;
import osc.packet;
import osc.bundle;


/++
+/
class PullServer {
private:
    UdpSocket _socket;
    ubyte[] recvBuffer;

public:
    ~this() {
        close();
    }

    this(ushort port) {
        this(new InternetAddress ("0.0.0.0", port));
    }

    ///
    this(InternetAddress internetAddress) {
        import std.socket;
        _socket = new UdpSocket();
        _socket.bind (internetAddress);
        recvBuffer = new ubyte[ushort.max];
    }

    const(Message)[] receive() {
        const(Message)[] messages;
        size_t l;

        do {
            l = _socket.receive(recvBuffer);
            if(l>0) {
                messages ~= Packet(recvBuffer[0..l]).messages;
            }
        } while(l>0);
        
        return messages;
    }

    void close() {
        _socket.close();
    }
}

/++
+/
class Server {
private:
    bool shouldRun;
    Messages _messages;
    Thread _thread;
    Socket socket;
    ubyte[] recvBuffer;
    
    void receive(Socket socket) {
        while(shouldRun) {
            ptrdiff_t l = socket.receive(recvBuffer);
            if (l != UdpSocket.ERROR) {
                _messages.pushMessages(Packet(recvBuffer[0..l]).messages);
            }
        }
    }

public:

    /// Construct a server
    this(ushort port) {
        this(new InternetAddress ("0.0.0.0", port));
    }
    
    ///
    this(InternetAddress internetAddress) {
        import std.socket;
        _messages = new Messages;
        socket = new UdpSocket();
        recvBuffer = new ubyte[ushort.max];
        socket.setOption(SocketOptionLevel.IP, SocketOption.RCVTIMEO, 16);
        socket.bind (internetAddress);

        shouldRun = true;
        _thread = new Thread(() => receive(socket));
        _thread.start();
    }
    
    ///
    ~this() {
        close();
    }

    const(Message)[] popMessages() {
        return _messages.popMessages;
    }

    void close() {
        if(_thread) {
            shouldRun = false;
            _thread.join;
        }
        if (socket) {
            socket.close();
        }
    }
}

/++
+/
private class Messages {
private:
        const(Message)[] _contents;
        Mutex mtx;

public:
    this() {
        mtx = new Mutex();
    }

    const(Message)[] popMessages() {
        mtx.lock; scope(exit)mtx.unlock;
        const(Message)[] result = cast(const(Message)[])(_contents);
        _contents = [];
        return result;
    }

    void pushMessages(const(Message)[] messages) {
        mtx.lock;
        _contents ~= cast(const(Message)[])messages;
        mtx.unlock;
    }

    size_t length() const {
        return _contents.length;
    }
}

private{
    const(Message)[] messages(in Packet packet) {
        const(Message)[] list;
        if(packet.hasMessage) {
            list ~= packet.message;
        }
        if(packet.hasBundle) {
            list = messagesRecur(packet.bundle);
        }
        return list;
        
    }
    
    const(Message)[] messagesRecur(in Bundle bundle) {
        const(Message)[] list;
        foreach (ref element; bundle.elements) {
            if(element.hasMessage) {
                list ~= element.message;
            }
            if(element.hasBundle) {
                list ~= element.bundle.messagesRecur;
            }
        }
        return list;
    }
}
