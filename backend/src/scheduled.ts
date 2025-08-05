// ABOUTME: Scheduled worker for pre-computing trending data
// ABOUTME: Runs every 30 seconds to keep cache warm

import { preComputeTrending } from './handlers/trending-api-optimized';

export default {
  /**
   * Scheduled handler - runs on cron schedule
   * Configure in wrangler.toml: crons = ["*/30 * * * * *"]
   */
  async scheduled(
    event: ScheduledEvent,
    env: Env,
    ctx: ExecutionContext
  ): Promise<void> {
    console.log(`Scheduled job started at ${new Date().toISOString()}`);
    
    try {
      // Pre-compute all trending combinations
      await preComputeTrending(env, ctx);
      
      console.log('Pre-computation completed successfully');
    } catch (error) {
      console.error('Pre-computation failed:', error);
      
      // Log failure
      await env.ANALYTICS_KV.put('precompute:last_run', JSON.stringify({
        timestamp: Date.now(),
        success: false,
        error: error.message
      }), { expirationTtl: 60 });
    }
  }
};