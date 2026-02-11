import abilityTest from './Ability.test';
import routeParamNormalizerTest from './RouteParamNormalizer.test';
import templateManagerPackTest from './TemplateManagerPack.test';
import sessionPlannerMicroContextTest from './SessionPlannerMicroContext.test';
import storyGenerationPipelineTest from './StoryGenerationPipeline.test';
import fsrsAlgorithmCacheTest from './FSRSAlgorithmCache.test';
import networkManagerTest from './NetworkManager.test';
import fsrsv5AlgorithmTest from './FSRSv5Algorithm.test';

export default function testsuite() {
  abilityTest();
  routeParamNormalizerTest();
  templateManagerPackTest();
  sessionPlannerMicroContextTest();
  storyGenerationPipelineTest();
  fsrsAlgorithmCacheTest();
  networkManagerTest();
  fsrsv5AlgorithmTest();
}
