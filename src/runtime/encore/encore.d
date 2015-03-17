/*
 * Encore DTrace provider.
 *
 */
provider encore {

  /*
   * Actor create probe.
   * Fires when an actor is created.
   *
   * Emits:
   *   class_name : actor class name
   *   id         : actor id
   *   size       : actor size
   *
   * Example:
   *   dtrace -n 'encore*:::actor_crate { printf("%s: %d\n", copyinstr(arg0), arg2) }'
   */
  probe actor_create(char *class_name, uint32_t id, uint32_t size);

  /*
   * Actor scheduled probe.
   * Fires when an actor has been scheduled on a pony worker thread.
   *
   * Emits:
   *   class_name : actor class name
   *   actor_id   : actor id
   *   thread_id  : pony thread id
   *   cpu        : cpu worker thread is running on
   *
   * Examples:
   *   -- class scheduled on CPU
   *   dtrace -n 'encore*:::actor_scheduled { printf("%s: %d\n", copyinstr(arg0), arg3) }'
   *   -- which CPUs have we been running on?
   *   dtrace -n 'encore*:::actor_scheduled { @ = quantize(arg3) }'
   *   -- run a program and show histogram over CPUs
   *   dtrace -n 'encore*:::actor_scheduled { @ = quantize(arg3) }' -c "./safe 1000000 7"
   */
  probe actor_scheduled(char *class_name, uint32_t id, 
			void *thread_id, uint32_t cpu);

  /*
   * Message send probe.
   * Fires when an actor sends a message to another actor.
   *
   * Emits:
   *   send_name : sending actor class name
   *   send_id   : sending actor id
   *   recv_name : receiving actor class name
   *   recv_id   : receiving actor id
   *   msg_name  : message name
   *   msg_id    : message id
   *   payload   : message arguments
   *
   * Examples:
   *
   * Macro:
   *   ENCORE_MESSAGE_SEND( type->class_name, type->id,
   *                        recv->class_name, recv->id,
   *                        msg->name, msg->id, payload )
   */
  probe message_send(char *send_name, uint32_t send_id,
		     char *recv_name, uint32_t recv_id,
		     char *msg_name, uint32_t msg_id,
		     void * payload);

  /*
   * Actor probes
   *
   * Probes:
   *
   *    encore$target:<exec name>:<actor name>$id:created
   *    encore$target:<exec name>:<actor name>$id:scheduled
   *    encore$target:<exec name>:<actor name>$id:<msg>:send
   *    encore$target:<exec name>:<actor name>$id:<msg>:receive
   *    encore$target:<exec name>:<actor name>$id:gc:start
   *    encore$target:<exec name>:<actor name>$id:gc:stop
   *
   */
};
