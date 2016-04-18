import herd.junc.api {

	Context,
	Message
}


"Implementation of [[herd.junc.api::Message]]."
by( "Lis" )
class MessageImpl<Body, Reply> (
	"Context to reply on." Context context,
	"Message body." shared actual Body body,
	"Handles message reply." variable Anything(Message<Reply, Body>)? replyHandler,
	"Handles message rejection." variable Anything(Throwable)? rejectHandler
)
		satisfies Message<Body, Reply>
{
	
	shared actual void reject( Throwable reason ) {
		if ( exists handler = rejectHandler ) {
			rejectHandler = null;
			replyHandler = null;
			context.executeWithArgument( handler, reason );
		}
	}
	
	shared actual void reply( Message<Reply, Body> repliedMessage ) {
		if ( exists handler = replyHandler ) {
			rejectHandler = null;
			replyHandler = null;
			context.executeWithArgument( handler, repliedMessage );
		}
	}
	
}


"Immediately rejects with give reason."
class RejectedMessage<Body, Reply> (
	"Message body." shared actual Body body,
	"Rejection reason." Throwable reason
)
		satisfies Message<Body, Reply>
{
	shared actual void reject( Throwable reason ) {}
	
	shared actual void reply( Message<Reply, Body> repliedMessage ) => repliedMessage.reject( reason );
}


class MessageWrapper<Body, Reply> (
	"Message to reply on." Message<Body, Reply> message,
	"Context to reply on." Context context,
	"Handles message reply." variable Anything()? replyHandler,
	"Handles message rejection." variable Anything(Throwable)? rejectHandler
	
)
		satisfies Message<Body, Reply>
{
	shared actual void reject( Throwable reason ) {
		message.reject( reason );
		if ( exists handler = rejectHandler ) {
			rejectHandler = null;
			replyHandler = null;
			context.executeWithArgument( handler, reason );
		}
	}
	
	shared actual void reply( Message<Reply, Body> repliedMessage ) {
		message.reply( repliedMessage );
		if ( exists handler = replyHandler ) {
			rejectHandler = null;
			replyHandler = null;
			context.execute( handler );
		}
	}
	
	shared actual Body body => message.body;
	
}
