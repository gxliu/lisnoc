/**
 * This file is part of LISNoC.
 *
 * LISNoC is free hardware: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as
 * published by the Free Software Foundation, either version 3 of
 * the License, or (at your option) any later version.
 *
 * As the LGPL in general applies to software, the meaning of
 * "linking" is defined as using the LISNoC in your projects at
 * the external interfaces.
 *
 * LISNoC is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public
 * License along with LISNoC. If not, see <http://www.gnu.org/licenses/>.
 *
 * =================================================================
 * This is a multiplexer that muxes several incoming vchannels to a
 * single one. It ensures wormhole forwarding in a first-come,
 * first-served way. There must not be two valid vchannels at the
 * same time, so it cannot be used as an arbiter!
 *  
 * (c) 2012 by the author(s)
 *
 * Author(s):
 *    Michael Tempelmeier, michael.tempelmeier@tum.de
 */

`include "lisnoc_def.vh"

module lisnoc_vc_multiplexer(/*AUTOARG*/
   // Outputs
   ready_o, valid_o, data_o,
   // Inputs
   clk, rst, valid_i, data_i, ready_i
   );

   parameter vchannels = 3;
   parameter flit_width = 32;

   input clk;
   input rst;

   //n-vchannel in
   input [vchannels-1:0] valid_i;
   output [vchannels-1:0] ready_o;
   input  [flit_width-1:0] data_i;

   //one vchannel out
   input  ready_i;
   output valid_o;
   output [flit_width-1:0] data_o;
 
   reg    state;
   reg    nxt_state;
`define STATE_READY 1'b0
`define STATE_VALID 1'b1
   
   reg [vchannels-1 :0]     channel_mask;
   reg [vchannels-1 :0]     nxt_channel_mask;
   
   assign data_o  = data_i;
   assign valid_o = |(valid_i & channel_mask);
   assign ready_o = channel_mask & {vchannels{ready_i}};

   
   always @ (*) begin : fsm_logic
      //default:
      nxt_state = state;
      nxt_channel_mask = channel_mask;
      
      case (state)
         `STATE_READY: begin
            if (ready_i) begin            
               if((data_i[flit_width-1:flit_width-2]  == `FLIT_TYPE_HEADER) && (|valid_i)) begin
                  //save the current vchannel if a new packet arrives
                  //if the packet is a single-flit we don't need this information since there are no
                  //following flits that have to be served on the same vchannel
                  nxt_state = `STATE_VALID;
                  nxt_channel_mask = valid_i; //save the current channel;
               end
            end
         end // case: `STATE_READY
        
         `STATE_VALID: begin
            if (ready_i) begin
               if((data_i[flit_width-1:flit_width-2] == `FLIT_TYPE_LAST) && (valid_i & channel_mask)) begin
                  //end of packet - we are ready for a new one
                  nxt_state = `STATE_READY;
                  nxt_channel_mask = {vchannels{1'b1}};
               end
            end                        
         end
        default: begin
           //nothing
        end
      endcase // case (state)
   end // block: fsm_logic
   
   
   always @ (posedge clk) begin : fsm_reg
      if (rst) begin
         state = `STATE_READY;
         channel_mask = {vchannels{1'b1}};
      end else begin
         state = nxt_state;
         channel_mask = nxt_channel_mask;
      end
   end
   
   
         

endmodule // lisnoc_vc_multiplexer