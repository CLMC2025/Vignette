import abilityTest from './Ability.test';
import routeParamNormalizerTest from './RouteParamNormalizer.test';
import templateManagerPackTest from './TemplateManagerPack.test';
import sessionPlannerMicroContextTest from './SessionPlannerMicroContext.test';
import storyGenerationPipelineTest from './StoryGenerationPipeline.test';

export default function testsuite() {
  abilityTest();
  routeParamNormalizerTest();
  templateManagerPackTest();
  sessionPlannerMicroContextTest();
  storyGenerationPipelineTest();
}
