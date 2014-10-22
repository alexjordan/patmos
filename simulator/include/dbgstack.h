/*
   Copyright 2012 Technical University of Denmark, DTU Compute.
   All rights reserved.

   This file is part of the Patmos simulator.

   Redistribution and use in source and binary forms, with or without
   modification, are permitted provided that the following conditions are met:

      1. Redistributions of source code must retain the above copyright notice,
         this list of conditions and the following disclaimer.

      2. Redistributions in binary form must reproduce the above copyright
         notice, this list of conditions and the following disclaimer in the
         documentation and/or other materials provided with the distribution.

   THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDER ``AS IS'' AND ANY EXPRESS
   OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
   OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN
   NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY
   DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
   (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
   LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
   ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
   (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
   THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

   The views and conclusions contained in the software and documentation are
   those of the authors and should not be interpreted as representing official
   policies, either expressed or implied, of the copyright holder.
 */

//
// Helper class for debug stack handling.
//

#ifndef PATMOS_DBGSTACK_H
#define PATMOS_DBGSTACK_H

#include <limits>
#include <ostream>
#include <vector>


#include "basic-types.h"

namespace patmos
{
  /// forward defs
  class simulator_t;


  /// Profiling information for functions.
  class dbgstack_t
  {
    private:

      /// dbgstack_frame_t - Data of a stack frame.
      class dbgstack_frame_t {
      public:
        // constructor
        dbgstack_frame_t(simulator_t &sim, uword_t call_address, 
                         uword_t return_offset, uword_t func);

        uword_t Call_address;
        uword_t function;
        uword_t ret_base;
        uword_t ret_offs;
        uword_t caller_tos_stackcache;
        uword_t caller_tos_shadowstack;
        
        // Should we print statistics when returning from this function?
        bool print_stats;
      };

      /// stack - Debug stack.
      std::vector<dbgstack_frame_t> stack;

      simulator_t &sim;
      
      std::ostream *debug_out;
      
      uword_t print_function;
      
      // True if we are currently collecting stats
      bool found_print_function;

      /// print_stackframe - Print a single debug stack frame to the stream
      /// @param callee the stack frame of the callee, or null if not available
      void print_stackframe(std::ostream &os, unsigned depth,
                            const dbgstack_frame_t &frame,
                            const dbgstack_frame_t *callee) const;
    public:
      /// Constructor
      dbgstack_t(simulator_t &s) : sim(s), debug_out(0), 
         print_function(std::numeric_limits<unsigned int>::max()),
         found_print_function(false)
      {
      }

      void print_function_stats(uword_t address, std::ostream &debug_out);
      
      /// initialize - Initialize the debug stack.
      void initialize(uword_t entry);

      /// finalize - Finalize the debug stack
      void finalize(void);

      unsigned size() const { return stack.size(); }
      
      /// is_active_frame - Returns true if a given frame is currently active.
      /// @param frame the frame to check
      bool is_active_frame(const dbgstack_frame_t &frame) const;

      /// push - Push the current state as a stack frame on the debug stack.
      /// Only used for debugging.
      /// @param call_offset offset of the current call instruction from its
      /// code block.
      /// @param return_offset return address for next instruction after 
      /// returning from the call.
      /// @param target The target of the call.
      void push(uword_t call_offset, uword_t return_offset, uword_t target);

      /// pop - Pop the top stack frame from the debug stack,
      /// if the given return info matches.
      /// Only used for debugging.
      void pop(uword_t return_base, uword_t return_offset);

      /// print - Print a short version of the debug stack trace.
      /// @param os An output stream.
      std::ostream &print_short(std::ostream &os) const;

      /// print - Print a debug stack trace.
      /// @param os An output stream.
      std::ostream &print(std::ostream &os) const;

  };

  std::ostream &operator<<(std::ostream &os, const dbgstack_t &dbgstack);

} // end namespace patmos


#endif // PATMOS_DBGSTACK_H
